import Foundation
import SwiftData

@Model
public final class CSMemory: CSIndexRecord {
    public typealias Data = MemoryItem
    
    @Attribute(.unique) public var id: UUID
    public var indexed: Bool
    
    public init(id: UUID, indexed: Bool = false) {
        self.id = id
        self.indexed = indexed
    }
    
    public static func fetch(byTaskID: UUID, _ context: ModelContext) throws -> CSMemory? {
        var fetch = FetchDescriptor<CSMemory>(predicate: #Predicate { $0.id == byTaskID })
        fetch.fetchLimit = 1
        return try context.fetch(fetch).first
    }
}
