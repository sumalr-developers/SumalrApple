import Foundation
import HTTPTypes
import SwiftUI

public struct SetupPage: View {
    @State var clientBuffer: RlamusClient? = nil

    let action: (RlamusClient) -> Void

    public init(action: @escaping (RlamusClient) -> Void) {
        self.action = action
    }

    public var body: some View {
        Form {
            BackendSection()
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

    public struct BackendSection: View {
        @Environment(\.rlamusClient) var rlamusClient

        @State var endpointBuffer = ""
        @State var verifyState: BackendVerifyState = .pending

        public init() {
        }

        public var body: some View {
            Section("Backend") {
                TextField("Rlamus server URL", text: $endpointBuffer)
                    .autocorrectionDisabled()
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                #endif
                    .textContentType(.URL)
                    .submitLabel(.done)
                    .onAppear {
                        endpointBuffer = rlamusClient.wrappedValue?.endpoint.absoluteString ?? ""
                    }
                BackendVerifyView(state: verifyState)
                    .task(id: endpointBuffer) {
                        verifyState = .pending
                        // throttle for 1sec
                        try? await Task.sleep(for: .seconds(1))

                        guard let endpointURL = URL(string: endpointBuffer) else {
                            verifyState = .invalidAddress
                            return
                        }
                        verifyState = .verifying
                        let newClient = RlamusClient(endpoint: endpointURL)
                        do throws (VerifyError) {
                            try await newClient.verify()
                            verifyState = .passed
                            rlamusClient.wrappedValue = newClient
                        } catch {
                            verifyState = .failed(error)
                        }
                    }
            }
        }
    }
}

enum BackendVerifyState {
    case pending
    case invalidAddress
    case verifying
    case passed
    case failed(VerifyError)
}

fileprivate struct BackendVerifyView: View {
    let state: BackendVerifyState

    var body: some View {
        HStack {
            switch state {
            case .pending:
                Text("Paused for input sattle")
                    .foregroundStyle(.secondary)
            case .invalidAddress:
                Image(systemName: "link")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16)
                    .foregroundStyle(.red)
                Text("Could not parse the URL")
            case .verifying:
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                Text("Verifying backend...")
            case .passed:
                Image(systemName: "checkmark.seal")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16)
                    .foregroundStyle(.green)
                Text("Valid backend")
            case let .failed(error):
                Image(systemName: "exclamationmark.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16)
                    .foregroundStyle(.red)
                switch error {
                case .invalidEndpoint:
                    Text("The URL is not supported")
                case let .invalidServer(compatVersion):
                    if let compatVersion {
                        Text("Invalid backend (compatibility version \(compatVersion))")
                    } else {
                        Text("Invalid backend (invalid signature)")
                    }
                case let .io(error):
                    Text("Network error. \(error.localizedDescription)")
                case let .unexpectedStatus(got):
                    Text("Invalid response. Got status \(got.code).")
                }
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        BackendVerifyView(state: .pending)
        BackendVerifyView(state: .verifying)
        BackendVerifyView(state: .invalidAddress)
        BackendVerifyView(state: .passed)

        BackendVerifyView(state: .failed(.invalidEndpoint))
        BackendVerifyView(state: .failed(.invalidServer(compatVersion: nil)))
        BackendVerifyView(state: .failed(.invalidServer(compatVersion: 0)))
        BackendVerifyView(state: .failed(.io(NSError())))
        BackendVerifyView(state: .failed(.unexpectedStatus(HTTPResponse.Status.badGateway)))
    }
    .padding()
}
