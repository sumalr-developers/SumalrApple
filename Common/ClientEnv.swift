import Foundation
import SwiftUI

extension EnvironmentValues {
    @Entry public var rlamusClient: Binding<RlamusClient?> = Binding.constant(nil)
}
