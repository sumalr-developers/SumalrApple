import Common
import Foundation
import SwiftData

public enum DeepLink: Hashable, Equatable {
    case memory(taskID: UUID)
}

public extension DeepLink {
    init?(url: URL) {
        guard url.scheme == DEEP_LINK_SCHEME else {
            return nil
        }
        switch url.host(percentEncoded: false) {
        case "memory":
            guard let id = url.pathComponents.drop(while: { $0 == "/" }).first,
                  let uuid = UUID(uuidString: id)
            else {
                return nil
            }
            self = .memory(taskID: uuid)
        default:
            return nil
        }
    }

    var url: URL {
        switch self {
        case let .memory(taskID):
            URL(string: "\(DEEP_LINK_SCHEME)://memory/\(taskID.uuidString)")!
        }
    }
}
