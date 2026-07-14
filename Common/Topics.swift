import ClusterKit
import Foundation
import SwiftData

public func getTopics(_ memoryItems: [MemoryItem], existing: [TopicItem], minSamples: Int, minClusterSize: Int) async -> [TopicItem] {
    if memoryItems.isEmpty {
        return []
    }
    let memByID = Dictionary(uniqueKeysWithValues: memoryItems.map { ($0.id, $0) })
    let memAndEmbeddings = memoryItems.compactMap { if let embedding = $0.embedding { MemoryEmbeddingItem(memoryID: $0.id, embedding: embedding) } else { nil } }
    let clusters = await (Task.detached {
        let hdbscan = CKHDBSCAN(memAndEmbeddings, minSamples: UInt32(minSamples), minClusterSize: UInt32(minClusterSize))
        return hdbscan.clusters
    }).value
    var memIDsByTopicID = Dictionary<PersistentIdentifier, Set<PersistentIdentifier>>(uniqueKeysWithValues: existing.compactMap { topic in
        guard let memories = topic.memories else {
            return nil
        }
        return (topic.id, Set(memories.map { $0.id }))
    })

    var results = Array(existing)
    for cluster in clusters {
        if cluster.isNoise {
            continue
        }
        let memIDs = Set(cluster.items.map { $0.memoryID })
        if let existingSubsetTopic = existing.first(where: { topic in memIDsByTopicID[topic.id]!.isSubset(of: memIDs) && !topic.isUserDefined }) {
            // update TopicItem content
            memIDsByTopicID[existingSubsetTopic.id] = memIDs
            let oldContent = existingSubsetTopic.memories
            if let oldContent {
                let oldIDs = Set(oldContent.map { $0.id })
                if oldIDs == memIDs {
                    continue
                }
            }
            existingSubsetTopic.memories = memoryItems.filter { memIDs.contains($0.id) }
            existingSubsetTopic.modification = .now
        } else {
            // create new TopicItem
            results.append(TopicItem(
                name: cluster.isNoise ? String(localized: "Unbounded") : nil,
                memories: cluster.items.map { memByID[$0.memoryID]! },
            ))
        }
    }
    return results
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
