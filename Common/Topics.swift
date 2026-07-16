import ClusterKit
import Foundation
import SwiftData

/// Recurse into the [MemoryItem]s, dividing until unable to
///
/// Returns clusters of [MemoryItem]s in a hierarchy inside of each cluster
/// the memories are somewhat related
public func getTopics<M: Sequence, T: Sequence>(_ memories: M, existing: T, minSamples: Int, minClusterSize: Int) async -> [TopicItem]
    where M.Element == MemoryItem, T.Element == TopicItem {
    return await getTopicsInternal(memories, existing: existing, minSamples: minSamples, minClusterSize: minClusterSize)
}

func getTopicsInternal<M: Sequence, T: Sequence>(_ memories: M, existing: T, parent: TopicItem? = nil, minSamples: Int, minClusterSize: Int) async -> [TopicItem]
    where M.Element == MemoryItem, T.Element == TopicItem {
    let memoryItems = Set(memories)
    if memoryItems.isEmpty {
        return []
    }
    let memByID = Dictionary(uniqueKeysWithValues: memoryItems.map { ($0.id, $0) })
    var topicByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
    let memAndEmbeddings = memoryItems.compactMap { if let embedding = $0.embedding { MemoryEmbeddingItem(memoryID: $0.id, embedding: embedding) } else { nil } }
    let clusters = await (Task.detached {
        let hdbscan = CKHDBSCAN(memAndEmbeddings, minSamples: UInt32(minSamples), minClusterSize: UInt32(minClusterSize))
        return hdbscan.clusters
    }).value

    var results = Set(topicByID.keys)
    var memIDsByTopicID = Dictionary<PersistentIdentifier, Set<PersistentIdentifier>>(uniqueKeysWithValues: results.map { id in
        let topic = topicByID[id]!
        guard let memories = topic.memories else {
            return (topic.id, Set())
        }
        return (topic.id, Set(memories.map { $0.id }))
    })

    for cluster in clusters {
        if cluster.isNoise {
            continue
        }
        let memIDs = Set(cluster.items.map { $0.memoryID })
        let thisTopic: TopicItem
        let subsets = results
            .filter({ id in !(topicByID[id]!.isUserDefined) && memIDsByTopicID[id]!.isSubset(of: memIDs) == true })
            .map({ topicByID[$0]! })
        if subsets.first(where: { $0.memories?.count == memIDs.count }) != nil {
            // skip exact matches
            continue
        }

        if let existingSubsetTopic = subsets.min(by: { ($0.memories?.count ?? 0) < ($1.memories?.count ?? 0) }) {
            let oldContent = existingSubsetTopic.memories
            if let oldContent {
                let oldIDs = Set(oldContent.map { $0.id })
                if oldIDs == memIDs {
                    continue
                }
            }
            // update existing TopicItem content
            memIDsByTopicID[existingSubsetTopic.id] = memIDs
            existingSubsetTopic.memories = memoryItems.filter { memIDs.contains($0.id) }
            existingSubsetTopic.modification = .now
            thisTopic = existingSubsetTopic
        } else {
            // create new TopicItem
            let newTopic = TopicItem(
                name: nil,
                memories: cluster.items.map { memByID[$0.memoryID]! },
                parent: parent
            )
            results.insert(newTopic.id)
            topicByID[newTopic.id] = newTopic
            memIDsByTopicID[newTopic.id] = Set(cluster.items.map { $0.memoryID })
            thisTopic = newTopic
        }
        // recursion
        let childrenTopics = await getTopicsInternal(memoryItems.filter({ memIDs.contains($0.id) }), existing: thisTopic.children ?? [], parent: thisTopic, minSamples: minSamples, minClusterSize: minClusterSize)
        if var children = thisTopic.children {
            children.append(contentsOf: childrenTopics)
            thisTopic.children = children
        } else {
            thisTopic.children = Array(childrenTopics)
        }

        if thisTopic.memories == nil {
            thisTopic.memories = []
        }
        for childTopic in childrenTopics {
            if let mem = childTopic.memories {
                thisTopic.memories?.append(contentsOf: mem)
            }
        }
    }
    return results.map { topicByID[$0]! }.filter { $0.parent == parent }
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
