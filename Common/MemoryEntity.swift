import AppIntents
import CoreSpotlight
import GeoToolbox
import SwiftData

public struct MemoryEntity: IndexedEntity {
    public let id: String
    
    public var title: String?
    public let summary: String?
    public let url: URL
    public var entryDate: Date
    
    public var displayRepresentation: DisplayRepresentation {
        if let title {
            DisplayRepresentation(stringLiteral: title)
        } else {
            DisplayRepresentation(title: "Unnamed memory")
        }
    }
    
    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Memory")
    }
    
    public var attributeSet: CSSearchableItemAttributeSet {
        let set = defaultAttributeSet
        set.contentDescription = summary
        set.addedDate = entryDate
        set.url = url
        return set
    }
    
    public struct DefaultQuery: EntityStringQuery {
        public typealias Entity = MemoryEntity
        
        @MainActor
        public func entities(for identifiers: [Entity.ID]) async throws -> [Entity] {
            try identifiers.compactMap { id in
                guard
                    let url = URL(string: id),
                    let deepLink = DeepLink(url: url),
                    case let .memory(taskID) = deepLink,
                    let item = try MemoryItem.fetch(taskID: taskID, modelContext: appModelContainer.mainContext)
                else {
                    return nil
                }
                return MemoryEntity(item)
            }
        }
        
        @MainActor
        public func entities(matching string: String) async throws -> [Entity] {
            let items = try appModelContainer.mainContext.fetch(FetchDescriptor<MemoryItem>(), batchSize: 50)
            return items.compactMap { item in
                if item.title?.localizedCaseInsensitiveContains(string) == true
                    || item.summary?.localizedCaseInsensitiveContains(string) == true {
                    return MemoryEntity(item)
                } else {
                    return nil
                }
            }
        }
        
        @MainActor
        public func suggestedEntities() async throws -> [Entity] {
            let descriptor = FetchDescriptor<MemoryItem>(sortBy: [SortDescriptor(\.creation, order: .reverse)])
            return (try appModelContainer.mainContext.fetch(descriptor)).map { MemoryEntity($0) }
        }
        
        public init() {}
    }
    
    public static let defaultQuery = DefaultQuery()
    
    public init(taskID: UUID, title: String?, summary: String?, url: URL, entryDate: Date) {
        id = "\(DEEP_LINK_SCHEME)://memory/\(taskID)"
        self.title = title
        self.summary = summary
        self.url = url
        self.entryDate = entryDate
    }
    
    public init(_ item: MemoryItem) {
        self.init(taskID: item.taskID, title: item.title, summary: item.summary, url: URL(string: item.url)!, entryDate: item.creation)
    }
}

public extension CSSearchableItem {
    convenience init(memoryEnitity: MemoryEntity) {
        self.init(uniqueIdentifier: memoryEnitity.id, domainIdentifier: "memory", attributeSet: memoryEnitity.attributeSet)
    }
}
