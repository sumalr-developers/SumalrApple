import Foundation
import Common
import SwiftData

struct OpenMemory: Encodable, Decodable, Hashable {
    let pk: PersistentIdentifier
    
    init(_ memory: MemoryItem) {
        self.pk = memory.id
    }
}
