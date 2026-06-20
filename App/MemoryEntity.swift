import AppIntents
import Common
import CoreSpotlight
import GeoToolbox
import SwiftData

@AppEntity(schema: .journal.entry)
struct MemoryEntity: IndexedEntity {
    let id: UUID
    var title: String?
    let summary: String?
    let url: URL?
    var entryDate: Date?

    var message: AttributedString? {
        if let summary {
            AttributedString(stringLiteral: summary)
        } else {
            nil
        }
    }

    var mediaItems: [IntentFile] { [] }
    var location: PlaceDescriptor? { nil }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: {
            if let title {
                LocalizedStringResource(stringLiteral: title)
            } else {
                "Unnamed memory"
            }
        }(), subtitle: {
            if let summary {
                LocalizedStringResource(stringLiteral: summary)
            } else {
                nil
            }
        }())
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let set = defaultAttributeSet
        set.textContent = summary
        set.addedDate = entryDate
        return set
    }

    struct DefaultQuery: EntityStringQuery {
        typealias Entity = MemoryEntity

        init() {
        }

        @MainActor
        func entities(for identifiers: [Entity.ID]) async throws -> [Entity] {
            try identifiers.compactMap { id in
                guard let item = try MemoryItem.fetch(taskID: id, modelContext: appModelContainer.mainContext) else {
                    return nil
                }
                return MemoryEntity(item)
            }
        }

        @MainActor
        func entities(matching string: String) async throws -> [Entity] {
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
        func suggestedEntities() async throws -> [Entity] {
            let descriptor = FetchDescriptor<MemoryItem>(sortBy: [SortDescriptor(\.creation, order: .reverse)])
            return (try appModelContainer.mainContext.fetch(descriptor)).map { MemoryEntity($0) }
        }
    }

    static let defaultQuery: DefaultQuery = DefaultQuery()

    init(_ item: MemoryItem) {
        id = item.taskID
        summary = item.summary
        url = URL(string: item.url)
        entryDate = item.creation
        title = item.title
    }
}
