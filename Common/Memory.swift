import Foundation
import RealmSwift

public class MemoryItem: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) public var url: String
    @Persisted public var title: String?
    @Persisted public var summary: String?
    @Persisted public var taskID: UUID
    @Persisted public var creation: Date

    public func streamTaskState(client: RlamusClient) -> some AsyncSequence<RlamusTaskState, Error> {
        client.streamTask(id: taskID).map { $0.state }
    }
}
