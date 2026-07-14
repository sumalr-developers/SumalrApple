import Foundation
import SwiftData

public let appModelContainer = try! ModelContainer(for: MemoryItem.self, TopicItem.self, EmbeddingModelItem.self)
public let spotlightModelContainer = try! ModelContainer(for: CSMemory.self, configurations: ModelConfiguration(url: FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: APP_GROUP_ID)!.appending(components: "Library", "Application Support", "spotlight-index.store"), cloudKitDatabase: .none))
