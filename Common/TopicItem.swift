import Foundation
import SwiftData

@Model
public class TopicItem {
    public var name: String?
    public var memories: [MemoryItem]?
    public var creation = Date.distantFuture
    public var modification = Date.distantFuture
    public var isUserDefined = false
    
    public init(name: String? = nil, isUserDefined: Bool = false, memories: [MemoryItem]) {
        self.name = name
        self.isUserDefined = isUserDefined
        self.memories = memories
        self.creation = .now
        self.modification = .now
    }
}
