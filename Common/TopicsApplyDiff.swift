import SwiftData

public func applyTopicModifications(_ modifications: [TopicModification], modelContext: ModelContext) {
    var topicByCreationHandle = [TopicCreationHandle: TopicItem]()
    func getTopicItem(reference: TopicReference) -> TopicItem {
        switch reference {
        case let .existing(topicItem):
            topicItem
        case let .created(handle):
            topicByCreationHandle[handle]!
        }
    }

    for operation in modifications {
        switch operation {
        case let .added(parent, memories, handle):
            var newTopic: TopicItem
            if let parent {
                let parentTopicItem = getTopicItem(reference: parent)
                if parentTopicItem.children == nil {
                    parentTopicItem.children = []
                }
                newTopic = TopicItem(memories: memories, parent: parentTopicItem)
                parentTopicItem.children?.append(newTopic)
            } else {
                newTopic = TopicItem(memories: memories)
                modelContext.insert(newTopic)
            }
            topicByCreationHandle[handle] = newTopic
        case let .removed(topicItem):
            modelContext.delete(topicItem)
            for (handle, item) in topicByCreationHandle {
                if item == topicItem {
                    topicByCreationHandle.removeValue(forKey: handle)
                    break
                }
            }
        case let .associate(memories, topicRef):
            let topic = getTopicItem(reference: topicRef)
            var existingMemories = Set(topic.memories ?? [])
            existingMemories.formUnion(memories)
            topic.memories = Array(existingMemories)
        case let .disassociate(memories, topicRef):
            let topic = getTopicItem(reference: topicRef)
            var existingMemories = Set(topic.memories ?? [])
            for mem in memories {
                existingMemories.remove(mem)
            }
            topic.memories = Array(existingMemories)
        }
    }
}

func applyTopicModifications(_ modifications: [TopicModification], rootNode: Node, nodeByTopic: borrowing [TopicItem: HashParentAndChildren], nodeByCreationHandle: inout [TopicCreationHandle: Node]) {
    func getNode(reference: TopicReference) -> Node {
        switch reference {
        case let .existing(topicItem):
            nodeByTopic[topicItem]!.wrappedValue
        case let .created(handle):
            nodeByCreationHandle[handle]!
        }
    }

    for operation in modifications {
        switch operation {
        case let .added(parent, memories, handle):
            var newNode: Node
            if let parent {
                let parent = getNode(reference: parent)
                newNode = Node(topicContainingMemories: memories.map { $0.id }, parent: parent)
                switch parent.kind {
                case let .topic(children):
                    parent.kind = .topic(children: children + [newNode])
                case let .root(children):
                    parent.kind = .root(children: children + [newNode])
                case .memory:
                    print("parent cannot be a memory")
                case .empty:
                    print("empty parent")
                }
            } else {
                newNode = Node(topicContainingMemories: memories.map { $0.id }, parent: rootNode)
                rootNode.kind = .root(children: (rootNode.children ?? []) + [newNode])
            }
            nodeByCreationHandle[handle] = newNode
        case let .removed(topicItem):
            let removal = nodeByTopic[topicItem]!
            for node in rootNode.children! {
                if removeNodeDFS(.init(wrappedValue: node), removing: removal) {
                    break
                }
            }
        case let .associate(memories, topic):
            let node = getNode(reference: topic)
            switch node.kind {
            case let .topic(children):
                node.kind = .topic(children: children + memories.map { Node(kind: .memory(id: $0.id), parent: node) })
            case let .root(children):
                node.kind = .root(children: children + memories.map { Node(kind: .memory(id: $0.id), parent: node) })
            case .memory:
                print("associate with memory node")
            case .empty:
                print("associate with empty node")
            }
        case let .disassociate(memories, topic):
            let node = getNode(reference: topic)
            switch node.kind {
            case let .topic(children):
                let memoryChildren = Set(children.compactMap { $0.memoryID }).subtracting(memories.map { $0.id })
                node.kind = .topic(children: children.filter({ $0.memoryID == nil }) + memoryChildren.map { Node(kind: .memory(id: $0), parent: node) })
            case let .root(children):
                let memoryChildren = Set(children.compactMap { $0.memoryID }).subtracting(memories.map { $0.id })
                node.kind = .root(children: children.filter({ $0.memoryID == nil }) + memoryChildren.map { Node(kind: .memory(id: $0), parent: node) })
            case .memory:
                print("disassociate from memory node")
            case .empty:
                print("disassociate from empty node")
            }
        }
    }
}

func removeNodeDFS(_ from: HashParentAndChildren, removing: HashParentAndChildren) -> Bool {
    var children = from.wrappedValue.children ?? []
    let removeAt = children.enumerated().firstIndex(where: { HashParentAndChildren(wrappedValue: $1) == removing })
    if let removeAt {
        children.remove(at: removeAt.base)
        from.wrappedValue.kind = .topic(children: children)
        return true
    }
    for child in children {
        if removeNodeDFS(.init(wrappedValue: child), removing: removing) {
            break
        }
    }
    return false
}
