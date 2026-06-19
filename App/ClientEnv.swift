import Common
import Foundation
import SwiftUI

extension EnvironmentValues {
    @Entry var getRlamusClient: () async throws(CancellationError) -> RlamusClient = { fatalError() }
}
