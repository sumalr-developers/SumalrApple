import Foundation
import SwiftData

@Model
public final class CSMemory: CSIndexRecord {
    public typealias Data = MemoryItem
    
    public var dataToken: DefaultHistoryToken
    public var date: Date
    
    public init(dataToken: DefaultHistoryToken, date: Date) {
        self.dataToken = dataToken
        self.date = date
    }
}
