import CoreSpotlight
import Foundation
import SwiftData
import ClusterKit

@Model
public final class MemoryItem {
    public var url: String = ""
    public var title: String?
    public var summary: String?
    public var taskID: UUID = UUID()
    public var creation: Date = Date.distantFuture
    /// Force fetch from remote server
    public var stale: Bool = false
    public var embedding: [Float32]?
    public var embeddingModel: EmbeddingModelItem?
    @Relationship(inverse: \TopicItem.memories)
    public var topics: [TopicItem]?

    public init(url: String, taskID: UUID) {
        self.url = url
        self.taskID = taskID
        creation = .now
    }

    public func streamTaskState(client: RlamusClient) -> some AsyncSequence<Optional<RlamusTaskState>, Error> {
        client.streamTask(id: taskID).map {
            if case let .some(task) = $0 {
                .some(task.state)
            } else {
                .none
            }
        }
    }

    public var searchableItem: CSSearchableItem {
        .init(memory: self)
    }
}

extension MemoryItem: CSIndexable {
    /// Associate with [CSMemory]
    public var csIndexID: UUID { taskID }
}

extension MemoryItem: ListItemDisplayProtocol {
}

extension MemoryItem: CKFloatArrayCovertible {
    public var floatArray: [Float32] {
        if let embedding {
            embedding
        } else {
            fatalError("reading embedding while it's empty")
        }
    }
}

public extension CSSearchableItem {
    convenience init(memory: MemoryItem) {
        let entity = MemoryEntity(memory)
        self.init(memoryEnitity: entity)
    }
}

extension MemoryItem {
    @MainActor
    public static func fetch(taskID: UUID, modelContext: ModelContext) throws -> MemoryItem? {
        var descriptor = FetchDescriptor<MemoryItem>(predicate: #Predicate { memory in
            memory.taskID == taskID
        })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    @MainActor
    public static func fetchAll(_ modelContext: ModelContext) throws -> [MemoryItem] {
        let descriptor = FetchDescriptor<MemoryItem>()
        return try modelContext.fetch(descriptor)
    }
}
