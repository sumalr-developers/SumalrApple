import ClusterKit
import Foundation
import SwiftData

/// Recurse into the [MemoryItem]s, dividing until unable to
///
/// Returns steps to achieve clusters of [MemoryItem]s in a hierarchy inside of each cluster
/// the memories are somewhat related
///
/// Noises are ignored
public func getTopicModifications<M: Sequence, T: Sequence>(
    _ memories: M,
    existing: T,
    parent: TopicItem? = nil,
    minSamples: Int,
    minClusterSize: Int
) -> [TopicModification] where M.Element == MemoryItem, T.Element == TopicItem {
    let memoryByID = Dictionary(uniqueKeysWithValues: memories.map { ($0.id, $0) })
    let memoryEmbeddingItems = memories.compactMap { memory in
        if let embedding = memory.embedding {
            return MemoryEmbeddingItem(memoryID: memory.id, embedding: embedding)
        } else {
            return nil
        }
    }
    func getRootTopics(_ items: [MemoryEmbeddingItem], parent: Node? = nil, leaves: inout [Node]) -> [Node] {
        let clusters = CKHDBSCAN(items, minSamples: UInt32(minSamples), minClusterSize: UInt32(minClusterSize))
            .clusters
        let topics: [Node] = if !clusters.isEmpty && !clusters.allSatisfy({ $0.isNoise }) {
            clusters.map { cluster in
                let node = Node(kind: .empty, parent: parent)
                var children = getRootTopics(cluster.items, parent: node, leaves: &leaves)
                if children.allSatisfy({
                    if case .memory = $0.kind {
                        true
                    } else {
                        false
                    }
                }) {
                    leaves.append(node)
                }
                node.kind = .topic(children: children)
                return node
            }
        } else { [] }
        return topics + items.map { Node(kind: .memory(id: $0.memoryID), parent: parent) }
    }

    var targetLeaves = [Node]()
    var existingTopicByNode = [HashParentAndChildren: TopicItem]()
    let targetRootTopics = getRootTopics(memoryEmbeddingItems, leaves: &targetLeaves)
    let existingRootTopics = existing.filter({ $0.parent == nil }).map { Node(topic: $0, parent: nil, association: &existingTopicByNode) }
    // add a fake root node to both
    let targetRootNode = Node(kind: .root(children: targetRootTopics), parent: nil)
    for topic in targetRootTopics {
        topic.parent = targetRootNode
    }
    let existingRootNode = Node(kind: .root(children: existingRootTopics), parent: nil)
    for topic in existingRootTopics {
        topic.parent = existingRootNode
    }

    if targetLeaves.isEmpty {
        return existingRootTopics.compactMap {
            if case .topic = $0.kind {
                TopicModification.removed(existingTopicByNode[.init(wrappedValue: $0)]!)
            } else {
                nil
            }
        }
    }

    var creationHandles = [TopicCreationHandle: Node]()
    return getTopicModificationsBottomUp(existing: existingRootNode.leaves, existingRoot: existingRootNode, target: targetLeaves, memoryByID: memoryByID, topicByNode: existingTopicByNode, nodeByCreationHandle: &creationHandles)
}

/// Depth based, recursively walks up each level, choosing the best match
func getTopicModificationsBottomUp(existing: [Node], existingRoot: borrowing Node, target: [Node], memoryByID: borrowing[PersistentIdentifier: MemoryItem], topicByNode: borrowing[HashParentAndChildren: TopicItem], nodeByCreationHandle: inout [TopicCreationHandle: Node]) -> [TopicModification] {
    var unresolvedTargetNodes = Set(target.map(HashParentAndChildren.init))
    var unresolvedExistingNodes = Set(existing.map(HashParentAndChildren.init))

    var results = [TopicModification]()
    for (target, match) in getBestMatchNoHierarchy(of: target, existing: existing) where match.score > 0.5 {
        unresolvedTargetNodes.remove(target)
        unresolvedExistingNodes.remove(match.existing)

        if match.score >= 1 {
            continue
        }
        results.append(contentsOf: getAssociationModifications(from: match, target: target.wrappedValue, memoryByID: memoryByID, topicByNode: topicByNode))
    }

    for node in unresolvedExistingNodes {
        if let topic = topicByNode[node], !topic.isUserDefined {
            // no matching target
            results.append(.removed(topic))
        }
    }

    let nodeByTopic = Dictionary(uniqueKeysWithValues: topicByNode.map { k, v in (v, k) })

    for node in unresolvedTargetNodes where !node.wrappedValue.isRoot {
        // no existing topic
        // walk one level up if possible, or create at root
        if let parent = node.wrappedValue.parent, !parent.isRoot {
            var preludes = getTopicModificationsBottomUp(of: node.wrappedValue, levitating: existing, existingRoot: existingRoot, memoryByID: memoryByID, topicByNode: topicByNode, nodeByCreationHandle: &nodeByCreationHandle)
            applyTopicModifications(preludes, rootNode: existingRoot, nodeByTopic: nodeByTopic, nodeByCreationHandle: &nodeByCreationHandle)

            results.append(contentsOf: preludes)
            preludesWalker: while let prelude = preludes.popLast() {
                switch prelude {
                case let .added(_, _, handle):
                    results.append(addTopic(topic: node.wrappedValue, parent: .created(handle), memoryByID: memoryByID, nodeByCreationHandle: &nodeByCreationHandle))
                    break preludesWalker
                default:
                    break
                }
            }
        } else {
            let op = getTopicModificationsTopDown(existing: existingRoot, targets: [node.wrappedValue], memoryByID: memoryByID, topicByNode: topicByNode)
            applyTopicModifications(op, rootNode: existingRoot, nodeByTopic: nodeByTopic, nodeByCreationHandle: &nodeByCreationHandle)
            results.append(contentsOf: op)
        }
    }

    return results
}

func getTopicModificationsBottomUp(of target: Node, levitating: [Node], existingRoot: Node, memoryByID: borrowing[PersistentIdentifier: MemoryItem], topicByNode: borrowing[HashParentAndChildren: TopicItem], nodeByCreationHandle: inout [TopicCreationHandle: Node]) -> [TopicModification] {
    let existing = Set(levitating.flatMap { $0.parent!.children?.filter({ $0.children != nil }) ?? [] }.map(HashAddress.init)).map { $0.wrappedValue }
    var unresolvedTarget = true

    var results = [TopicModification]()
    for (target, match) in getBestMatchNoHierarchy(of: [target], existing: existing) where match.score > 0.5 {
        unresolvedTarget = false

        if match.score >= 1 {
            continue
        }
        results.append(contentsOf: getAssociationModifications(from: match, target: target.wrappedValue, memoryByID: memoryByID, topicByNode: topicByNode))
    }
    
    if !unresolvedTarget {
        return results
    }

    let nodeByTopic = Dictionary(uniqueKeysWithValues: topicByNode.map { k, v in (v, k) })

    // no existing topic
    // walk one level up if possible, or create at root
    if let parent = target.parent, !parent.isRoot {
        var preludes = getTopicModificationsBottomUp(of: parent, levitating: existing, existingRoot: existingRoot, memoryByID: memoryByID, topicByNode: topicByNode, nodeByCreationHandle: &nodeByCreationHandle)
        applyTopicModifications(preludes, rootNode: existingRoot, nodeByTopic: nodeByTopic, nodeByCreationHandle: &nodeByCreationHandle)

        results.append(contentsOf: preludes)
        preludesWalker: while let prelude = preludes.popLast() {
            switch prelude {
            case let .added(_, _, handle):
                results.append(addTopic(topic: target, parent: .created(handle), memoryByID: memoryByID, nodeByCreationHandle: &nodeByCreationHandle))
                break preludesWalker
            default:
                break
            }
        }
    } else {
        let op = getTopicModificationsTopDown(existing: existingRoot, targets: [target], memoryByID: memoryByID, topicByNode: topicByNode)
        applyTopicModifications(op, rootNode: existingRoot, nodeByTopic: nodeByTopic, nodeByCreationHandle: &nodeByCreationHandle)
        results.append(contentsOf: op)
    }

    return results
}

func addTopic(topic: Node, parent: TopicReference?, memoryByID: borrowing [PersistentIdentifier: MemoryItem], nodeByCreationHandle: inout [TopicCreationHandle: Node]) -> TopicModification {
    if case let .topic(children) = topic.kind {
        let memories = children.compactMap { node in
            switch node.kind {
            case let .memory(id):
                memoryByID[id]!
            default:
                nil
            }
        }
        let handle = TopicCreationHandle()
        nodeByCreationHandle[handle] = topic
        return .added(parent: parent, memories: Set(memories), handle: handle)
    } else {
        fatalError()
    }
}

/// [existing] is not compared, only its children.
/// Only partiality of operations (add, associate, disassociation) are available.
/// It is treated as known information that [existing] is guaranteed to be the parent node of [targets] in the resulting tree.
func getTopicModificationsTopDown(existing: Node, targets: [Node], memoryByID: borrowing[PersistentIdentifier: MemoryItem], topicByNode: borrowing[HashParentAndChildren: TopicItem]) -> [TopicModification] {
    var results = [TopicModification]()
    var unresolvedTargets = Set(targets.map(HashParentAndChildren.init))

    for (target, match) in getBestMatchNoHierarchy(of: targets, existing: existing.children ?? []) where match.score > 0.5 {
        unresolvedTargets.remove(target)
        if match.score >= 1 {
            continue
        }

        // handles memory
        results.append(contentsOf: getAssociationModifications(from: match, target: target.wrappedValue, memoryByID: memoryByID, topicByNode: topicByNode))

        // handles subtopics
        results.append(contentsOf: getTopicModificationsTopDown(existing: match.existing.wrappedValue, targets: target.wrappedValue.children?.filter({ $0.children != nil }) ?? [], memoryByID: memoryByID, topicByNode: topicByNode))
    }

    func getTopicReference(_ node: Node) -> TopicReference? {
        switch node.kind {
        case .root:
            nil
        case .topic:
            .existing(topicByNode[.init(wrappedValue: node)]!)
        case .memory:
            fatalError()
        case .empty:
            fatalError()
        }
    }
    func getAddOpRecursively(for node: Node, parent: TopicReference?) -> [TopicModification] {
        let memories: [MemoryItem] = node.children?.compactMap { if let memoryID = $0.memoryID { memoryByID[memoryID]! } else { nil } } ?? []
        let creationHandle = TopicCreationHandle()
        var results = [TopicModification](arrayLiteral: .added(parent: parent, memories: Set(memories), handle: creationHandle))
        for subtopic in node.children ?? [] where subtopic.children != nil {
            results.append(contentsOf: getAddOpRecursively(for: subtopic, parent: .created(creationHandle)))
        }
        return results
    }

    for node in unresolvedTargets {
        // create under [existing]
        results.append(contentsOf: getAddOpRecursively(for: node.wrappedValue, parent: getTopicReference(existing)))
    }

    return results
}

func getAssociationModifications(from match: MatchResult, target: Node, memoryByID: borrowing[PersistentIdentifier: MemoryItem], topicByNode: borrowing[HashParentAndChildren: TopicItem]) -> [TopicModification] {
    var results = [TopicModification]()

    let targetChildren = Set(target.children?.map(HashChildren.init) ?? [])
    let existingChilren = Set(match.existing.wrappedValue.children?.map(HashChildren.init) ?? [])
    let intersection = targetChildren.intersection(existingChilren)

    let surging = targetChildren.subtracting(intersection).compactMap { $0.wrappedValue.memoryID }
    if !surging.isEmpty, let topic = topicByNode[match.existing] {
        results.append(.associate(memories: Set(surging.map { memoryByID[$0]! }), topic: .existing(topic)))
    }

    let sinking = existingChilren.subtracting(intersection).compactMap { $0.wrappedValue.memoryID }
    if !sinking.isEmpty, let topic = topicByNode[match.existing] {
        results.append(.disassociate(memories: Set(sinking.map { memoryByID[$0]! }), topic: .existing(topic)))
    }

    return results
}

func getBestMatchNoHierarchy(of target: [Node], existing: [Node]) -> [HashParentAndChildren: MatchResult] {
    var result = [HashParentAndChildren: MatchResult]()
    for target in target {
        for existing in existing {
            if case let .topic(targetChildren) = target.kind,
               case let .topic(existingChildren) = existing.kind {
                let score = Float(Set(targetChildren.map(HashChildren.init)).intersection(existingChildren.map(HashChildren.init)).count * 2) / Float(targetChildren.count + existingChildren.count)
                if (result[.init(wrappedValue: target)]?.score ?? 0) < score {
                    let group = MatchResult(existing: .init(wrappedValue: existing), score: score)
                    result[.init(wrappedValue: target)] = group
                }
            } else if case .root = target.kind, case .root = existing.kind {
                result[.init(wrappedValue: target)] = MatchResult(existing: .init(wrappedValue: existing), score: 1)
            }
        }
    }
    return result
}

public enum TopicModification: Hashable {
    case added(parent: TopicReference?, memories: Set<MemoryItem>, handle: TopicCreationHandle)
    case removed(TopicItem)
    case associate(memories: Set<MemoryItem>, topic: TopicReference)
    case disassociate(memories: Set<MemoryItem>, topic: TopicReference)
}

public enum TopicReference: Hashable {
    case existing(TopicItem)
    case created(TopicCreationHandle)
}

public struct TopicCreationHandle: Hashable {
    let uuid: UUID

    init() {
        uuid = UUID()
    }
}

class Node {
    var kind: NodeKind
    var parent: Node?

    init(kind: NodeKind, parent: Node?) {
        self.kind = kind
        self.parent = parent
    }

    var children: [Node]? {
        get {
            switch kind {
            case let .topic(children):
                children
            case let .root(children):
                children
            default:
                nil
            }
        }
        set {
            if let newValue {
                switch kind {
                case .root:
                    kind = .root(children: newValue)
                case .topic:
                    kind = .topic(children: newValue)
                case .memory:
                    fatalError("setting children of memory kind is unsupported")
                case .empty:
                    fatalError("setting children of emoty kind is unsupported")
                }
            } else {
                print("setting children of node as nil is probably unintended and undesired")
                kind = .empty
            }
        }
    }

    var memoryID: PersistentIdentifier? {
        switch kind {
        case let .memory(id):
            id
        default:
            nil
        }
    }

    // leaves are **topic** kind with no other topic children
    var leaves: [Node] {
        if let children {
            let topics = children.filter {
                switch $0.kind {
                case .topic:
                    return true
                default:
                    return false
                }
            }
            return if topics.isEmpty {
                [self]
            } else {
                topics.flatMap {
                    if case .topic = $0.kind {
                        $0.leaves
                    } else {
                        fatalError()
                    }
                }
            }
        } else {
            return []
        }
    }

    var isRoot: Bool {
        switch kind {
        case .root:
            true
        default:
            false
        }
    }
}

enum NodeKind {
    case root(children: [Node])
    case topic(children: [Node])
    case memory(id: PersistentIdentifier)
    case empty
}

extension Node {
    convenience init<W: Wrapping>(topic: TopicItem, parent: Node?, association: inout [W: TopicItem]) {
        self.init(kind: .empty, parent: parent)
        var children = topic.children?.map { Node(topic: $0, parent: self, association: &association) } ?? []
        children.append(contentsOf: topic.memories?.map { Node(kind: .memory(id: $0.id), parent: self) } ?? [])
        kind = .topic(children: children)
        association[.init(wrappedValue: self)] = topic
    }

    convenience init<M: Sequence>(topicContainingMemories memories: M, parent: Node?) where M.Element == PersistentIdentifier {
        self.init(kind: .empty, parent: parent)
        let children = memories.map { Node(kind: .memory(id: $0), parent: self) }
        kind = .topic(children: children)
    }
}

protocol Wrapping: Hashable {
    init(wrappedValue: Node)
}

struct HashParentAndChildren: Wrapping {
    let wrappedValue: Node
}

struct HashChildren: Wrapping {
    let wrappedValue: Node
}

struct HashAddress: Wrapping {
    let wrappedValue: Node
}

extension HashParentAndChildren: Equatable {
    static func == (lhs: borrowing HashParentAndChildren, rhs: borrowing HashParentAndChildren) -> Bool {
        HashChildren(wrappedValue: lhs.wrappedValue) == HashChildren(wrappedValue: rhs.wrappedValue) && (
            (lhs.wrappedValue.parent == nil && rhs.wrappedValue.parent == nil)
                || (lhs.wrappedValue.parent != nil && rhs.wrappedValue.parent != nil
                    && HashAddress(wrappedValue: lhs.wrappedValue.parent!) == HashAddress(wrappedValue: rhs.wrappedValue.parent!)))
    }
}

extension HashParentAndChildren: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(HashChildren(wrappedValue: wrappedValue))
        if let parent = wrappedValue.parent {
            hasher.combine(HashAddress(wrappedValue: parent))
        }
    }
}

enum NodeKindHashingChildren: Hashable {
    case root(children: [HashChildren])
    case topic(children: [HashChildren])
    case memory(id: PersistentIdentifier)
    case empty

    init(kind: NodeKind) {
        switch kind {
        case let .topic(children):
            self = .topic(children: children.map(HashChildren.init))
        case let .root(children):
            self = .root(children: children.map(HashChildren.init))
        case let .memory(id):
            self = .memory(id: id)
        case .empty:
            self = .empty
        }
    }
}

extension HashChildren: Equatable {
    static func == (lhs: borrowing HashChildren, rhs: borrowing HashChildren) -> Bool {
        NodeKindHashingChildren(kind: lhs.wrappedValue.kind) == NodeKindHashingChildren(kind: rhs.wrappedValue.kind)
    }
}

extension HashChildren: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(NodeKindHashingChildren(kind: wrappedValue.kind))
    }
}

extension HashAddress: Equatable {
    static func == (lhs: borrowing HashAddress, rhs: borrowing HashAddress) -> Bool {
        Unmanaged.passUnretained(lhs.wrappedValue).toOpaque() == Unmanaged.passUnretained(rhs.wrappedValue).toOpaque()
    }
}

extension HashAddress: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(Unmanaged.passUnretained(wrappedValue).toOpaque())
    }
}

public nonisolated struct MemoryEmbeddingItem: CKFloatArrayCovertible, Sendable {
    public let memoryID: MemoryItem.ID
    public let embedding: [Float]

    public var floatArray: [Float] { embedding }

    public init(memoryID: MemoryItem.ID, embedding: [Float]) {
        self.memoryID = memoryID
        self.embedding = embedding
    }
}

struct MatchResult: Hashable {
    let existing: HashParentAndChildren
    let score: Float
}
