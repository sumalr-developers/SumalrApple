import Common
import Foundation
import SwiftUI

extension EnvironmentValues {
    @Entry var rlamusClient: Binding<RlamusClient?> = Binding.constant(nil)
}
