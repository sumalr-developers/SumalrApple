import AppIntents
import Common
import SwiftData
#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

@AppIntent(schema: .system.open)
struct OpenMemoryIntent: OpenIntent {
    var target: MemoryEntity
    static let openAppWhenRun: Bool = true
    static let isDiscoverable: Bool = true
    static let title: LocalizedStringResource = "Open memory"

    @MainActor
    func perform() async throws -> some IntentResult {
        #if os(iOS)
            await UIApplication.shared.open(DeepLink.memory(taskID: target.id).url)
        #elseif os(macOS)
            NSWorkspace.shared.open(DeepLink.memory(taskID: target.id).url)
        #endif
        return .result()
    }
}

enum OpenMemoryError: Error {
    case notFound
}

extension OpenMemoryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notFound:
            String(localized: "Specified memory couldn't be found")
        }
    }
}
