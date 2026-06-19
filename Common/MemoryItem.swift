import Foundation
import Realm
import RealmSwift

public class MemoryItem: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) public var _id: ObjectId = ObjectId()
    @Persisted public var url: String
    @Persisted public var title: String?
    @Persisted public var summary: String?
    @Persisted public var taskID: UUID
    @Persisted public var creation: Date

    convenience init(id: ObjectId) {
        self.init()
        _id = id
    }

    public func streamTaskState(client: RlamusClient) -> some AsyncSequence<RlamusTaskState, Error> {
        client.streamTask(id: taskID).map { $0.state }
    }
}
