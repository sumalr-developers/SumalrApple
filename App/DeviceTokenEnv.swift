import Foundation
import SwiftUI

extension EnvironmentValues {
    var deviceToken: Data? {
        get { self[DeviceTokenEnvKey.self] }
        set { self[DeviceTokenEnvKey.self] = newValue }
    }
}

struct DeviceTokenEnvKey: EnvironmentKey {
    static let defaultValue: Data? = nil
}
