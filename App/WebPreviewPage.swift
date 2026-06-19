import Foundation
import SwiftUI
import WebKit
@_spi(Advanced) import SwiftUIIntrospect

struct WebPreviewPage: View {
    @Environment(\.errorHandler) var errorHandler

    @Binding var webPage: WebPage
    let action: (URL, String) async -> Void

    @State private var urlBuffer = ""
    @State private var showInvalidUrlBuffer = false
    @State private var activeActionTask: Task<(), Error>? = nil

    var body: some View {
        Group {
            if let url = webPage.url {
                webView
                    .onAppear {
                        urlBuffer = url.absoluteString
                    }
            } else {
                starterPage
                    .padding()
            }
        }
        .alert("Invalid address", isPresented: $showInvalidUrlBuffer) {
            Button(role: .close) {
                showInvalidUrlBuffer = false
            }
        } message: {
            Text("Could not parse the address of your input")
        }
    }

    var webView: some View {
        ZStack(alignment: .bottom) {
            WebView(webPage)
                .webViewLinkPreviews(.enabled)
                .webViewBackForwardNavigationGestures(.enabled)
                .webViewTextSelection(.enabled)
                .webViewMagnificationGestures(.enabled)
                .webViewElementFullscreenBehavior(.enabled)
                .task {
                    while true {
                        do {
                            for try await event in webPage.navigations {
                                switch event {
                                case .startedProvisionalNavigation:
                                    urlBuffer = webPage.url?.absoluteString ?? ""
                                    activeActionTask?.cancel()
                                    activeActionTask = nil
                                default:
                                    break
                                }
                            }
                        } catch {
                            // noop
                        }
                    }
                }
            VStack(spacing: 8) {
                Button("Use", systemImage: "camera.viewfinder") {
                    activeActionTask = Task { @MainActor in
                        var countdown = 10
                        while webPage.title.isEmpty && countdown > 0 {
                            try? await Task.sleep(for: .milliseconds(500))
                            countdown -= 1
                        }
                        await action(webPage.url!, webPage.title)
                        activeActionTask = nil
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(activeActionTask != nil)
                .shadow(radius: 1)
                navigationBar
                    .glassEffect(.regular)
                    .padding()
            }
        }
    }

    var starterPage: some View {
        VStack {
            Spacer()
            Image(systemName: "network")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48)
            Spacer()
            navigationBar
        }
    }

    var navigationBar: some View {
        NavigationBar(content: $urlBuffer, isLoading: webPage.isLoading)
            .submitLabel(.go)
            .onSubmit {
                if let url = URL(string: urlBuffer) {
                    webPage.load(URLRequest(url: url))
                } else {
                    showInvalidUrlBuffer = true
                }
            }
    }
}

fileprivate struct NavigationBar: View {
    @Binding var content: String
    let isLoading: Bool

    var body: some View {
        HStack {
            TextField("URL", text: $content, prompt: Text("Enter website address"))
            #if os(iOS)
                .introspect(.textField, on: .iOS(.v13...)) { textField in
                    textField.clearButtonMode = .whileEditing
                }
                .textInputAutocapitalization(.never)
            #endif
                .autocorrectionDisabled()
                .textContentType(.URL)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .textFieldStyle(.plain)
                .padding(.horizontal)
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .padding(.trailing, 8)
            }
        }
        .background(Capsule().foregroundStyle(.primary.opacity(0.2)))
    }
}

#Preview {
    WebPreviewPage(webPage: Binding.constant(WebPage())) { _, _ in
    }
}
