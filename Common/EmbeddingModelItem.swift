import Foundation
import SwiftData

@Model
public class EmbeddingModelItem {
    public var name: String?
    public var backendName: String?
    @Relationship(inverse: \MemoryItem.embeddingModel) var memories: [MemoryItem]?
    
    public init(name: String, backendName: String) {
        self.name = name
        self.backendName = backendName
    }
    
    public static func fetchOrCreate(name: String, backendName: String, context: ModelContext) throws -> EmbeddingModelItem {
        var fetcher = FetchDescriptor<EmbeddingModelItem>(predicate: #Predicate { $0.name == name && $0.backendName == backendName })
        fetcher.fetchLimit = 1
        return try context.fetch(fetcher).first ?? EmbeddingModelItem(name: name, backendName: backendName)
    }
}
