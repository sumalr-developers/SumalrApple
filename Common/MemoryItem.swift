import CoreSpotlight
import Foundation
import SwiftData

@Model
public final class MemoryItem: CSIndexable {
    public var url: String = ""
    public var title: String?
    public var summary: String?
    public var taskID: UUID = UUID()
    public var creation: Date = Date.distantFuture
    /// Force fetch from remote server
    public var stale: Bool = false

    /// Associate with [CSMemory]
    public var csIndexID: UUID { taskID }

    public init(url: String, taskID: UUID) {
        self.url = url
        self.taskID = taskID
        creation = .now
    }

    public func streamTaskState(client: RlamusClient) -> some AsyncSequence<RlamusTaskState, Error> {
        client.streamTask(id: taskID).map { $0.state }
    }

    public var searchableItem: CSSearchableItem {
        .init(memory: self)
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
