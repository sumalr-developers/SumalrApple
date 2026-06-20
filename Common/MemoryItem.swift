import Foundation
import SwiftData

@Model
public final class MemoryItem {
    public var url: String = ""
    @Attribute(.spotlight) public var title: String?
    @Attribute(.spotlight) public var summary: String?
    public var taskID: UUID = UUID()
    public var creation: Date = Date.distantFuture
    
    public init(url: String, taskID: UUID) {
        self.url = url
        self.taskID = taskID
        self.creation = .now
    }

    public func streamTaskState(client: RlamusClient) -> some AsyncSequence<RlamusTaskState, Error> {
        client.streamTask(id: taskID).map { $0.state }
    }
}
