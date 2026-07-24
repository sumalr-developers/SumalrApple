import Foundation
import SwiftData

@Model
public class TopicItem {
    public var name: String?
    public var memories: [MemoryItem]?
    public var creation = Date.distantFuture
    public var modification = Date.distantFuture
    public var isUserDefined = false
    public var parent: TopicItem?

    @Relationship(deleteRule: .cascade, inverse: \TopicItem.parent)
    public var children: [TopicItem]?

    public init<M: Sequence>(name: String? = nil, isUserDefined: Bool = false, memories: M, parent: TopicItem? = nil)
        where M.Element == MemoryItem {
        self.name = name
        self.isUserDefined = isUserDefined
        self.memories = Array(memories)
        creation = .now
        modification = .now
        self.parent = parent
    }
}
