import Common
import Foundation
import HTTPTypes
import SwiftUI

struct AccountPage: View {
    var body: some View {
        Form {
            SetupPage.BackendSection()
        }
        .formStyle(.grouped)
        .padding()
    }
}

