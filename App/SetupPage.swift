import Foundation
import SwiftUI
import Common

struct SetupPage: View {
    @State var clientBuffer: RlamusClient? = nil
    
    let action: (RlamusClient) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                AccountPage.BackendSection()
                    .environment(\.rlamusClient, $clientBuffer)
                Section {
                    Button("Continue", role: .confirm) {
                        action(clientBuffer!)
                    }
                    .disabled(clientBuffer == nil)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Setup")
        }
    }
}
