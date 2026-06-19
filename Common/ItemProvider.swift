import Foundation

extension NSItemProvider {
    public func loadObject<T>(ofType: T.Type) async throws -> T
        where T: _ObjectiveCBridgeable, T._ObjectiveCType: NSItemProviderReading, T: Sendable {
        return try await withCheckedThrowingContinuation { continuation in
            _ = self.loadObject(ofClass: ofType) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: item!)
            }
        }
    }
}
