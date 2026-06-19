import Foundation
import Common
import RealmSwift

struct OpenMemory: Encodable, Decodable, Hashable {
    let pk: ObjectId
    
    init(_ memory: MemoryItem) {
        self.pk = memory._id
    }
}
