import BinaryCodable
import Foundation
import SwiftData

public enum DeepLink: Hashable, Equatable {
    case memory(taskID: UUID)
    case topic(id: PersistentIdentifier)
}

extension DeepLink {
    public init?(url: URL) {
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
        case "topic":
            let decoder = JSONDecoder()
            guard let id = url.pathComponents.drop(while: { $0 == "/" }).first,
                  let binary = Data(base64URLEncoded: id),
                  let pid: PersistentIdentifier = try? decoder.decode(PersistentIdentifier.self, from: binary)
            else {
                return nil
            }
            self = .topic(id: pid)
        default:
            return nil
        }
    }

    public var url: URL {
        switch self {
        case let .memory(taskID):
            return URL(
                string: "\(DEEP_LINK_SCHEME)://memory/\(taskID.uuidString)"
            )!
        case let .topic(id):
            let encoder = JSONEncoder()
            let base62 = try! encoder.encode(id).base64URLEncodedString()
            return URL(string: "\(DEEP_LINK_SCHEME)://topic/\(base62)")!
        }
    }
}

extension Data {
    fileprivate func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }

    fileprivate init?(
        base64URLEncoded: String,
        options: Data.Base64DecodingOptions = []
    ) {
        var base64 = base64URLEncoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Restore padding
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        self.init(
            base64Encoded: base64,
            options: options
        )
    }
}
