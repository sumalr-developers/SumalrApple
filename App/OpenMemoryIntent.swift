import AppIntents
import Common
import SwiftData
#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

struct OpenMemoryIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open memory"
    @Parameter(title: "Memory", requestValueDialog: "Which memory?")
    var target: MemoryEntity

    static let openAppWhenRun: Bool = true
    static let isDiscoverable: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        #if os(iOS)
            await UIApplication.shared.open(URL(string: target.id)!)
        #elseif os(macOS)
            NSWorkspace.shared.open(URL(string: target.id)!)
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
