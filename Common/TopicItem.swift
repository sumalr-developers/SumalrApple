import Foundation

public class TopicItem : Identifiable {
    public var id: UUID
    public var name: String?
    public var memories: [MemoryItem]

    public init(id: UUID, name: String? = nil, memories: [MemoryItem]) {
        self.id = id
        self.name = name
        self.memories = memories
    }
}
