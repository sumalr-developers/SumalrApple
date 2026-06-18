import Foundation
import SwiftUI
import Logging

extension EnvironmentValues {
    @Entry var errorHandler: ErrorHandler = .init()
}

@Observable
class ErrorHandler {
    var current: (any Error)? = nil
    
    func runCatching<R>(block: () throws -> R) -> Result<R, Error> {
        do {
            return .success(try block())
        } catch {
            current = error
            appLogger.error("caught global", error: error)
            return .failure(error)
        }
    }
    
    func runCatching<R>(block: () async throws -> R) async -> Result<R, Error> {
        do {
            return .success(try await block())
        } catch {
            current = error
            appLogger.error("caught global", error: error)
            return .failure(error)
        }
    }
}
