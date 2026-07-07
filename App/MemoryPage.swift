import Common
import Foundation
import SwiftUI

struct MemoryPage: View {
    @Environment(\.openURL) var openURL
    @Environment(\.getRlamusClient) var getRlamusClient
    @Environment(\.tasks) var tasks

    @State var summary: String = ""
    @State private var retryState: RetryState? = nil
    
    var isLoading: Bool {
        item != nil && item?.summary == nil
    }

    let item: TrackedTask?
    init(_ item: TrackedTask? = nil) {
        self.item = item
    }

    var body: some View {
        Group {
            if let item {
                present(item)
            } else {
                Text("Item not found")
            }
        }
        .alert(error: Binding(get: {
            if case let .error(err) = retryState {
                err
            } else {
                nil
            }
        }, set: {
            if let newValue = $0 {
                retryState = .error(newValue)
            } else {
                retryState = nil
            }
        })) {
            Button(role: .cancel) {
                retryState = nil
            }
        }
        .alert("Removed from server", isPresented: Binding(get: {
            if case .notFound = retryState {
                true
            } else {
                false
            }
        }, set: { newValue in
            if newValue {
                retryState = .notFound
            } else {
                retryState = nil
            }
        })) {
            Button(role: .close) {
                retryState = nil
            }
        } message: {
            Text("This memory has been deleted from the remote server, therehence impossible to retry in place. You can remove it and create a new one manually")
        }
    }

    func present(_ item: TrackedTask) -> some View {
        ScrollView(.vertical) {
            VStack {
                Group {
                    if let markdown = try? AttributedString(markdown: summary) {
                        Text("\(markdown)")
                    } else {
                        Text(summary)
                    }
                }
                .textSelection(.enabled)
                
                if isLoading {
                    ProgressView(value: item.progress)
                        .frame(maxWidth: 150)
                }
                
                Text("Created \(Text(item.creation, style: .relative)) ago")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .safeAreaPadding(.bottom)
            }
            .padding(.horizontal)
            .onAppear {
                if let summary = item.value.summary {
                    self.summary = summary
                }
            }
            .onChange(of: item.value) { _, newValue in
                if let summary = newValue.summary {
                    self.summary = summary
                }
            }
        }
        .alert("Refresh Summarization", isPresented: Binding(get: {
            if case .waitingForConfirmation = retryState {
                true
            } else {
                false
            }
        }, set: { newValue in
            if newValue {
                retryState = .waitingForConfirmation
            } else {
                retryState = nil
            }
        })) {
            Button("Continue", role: .confirm) {
                Task {
                    guard let tasks else {
                        return
                    }
                    do {
                        let client = try await getRlamusClient()
                        try await client.patchTask(id: item.value.id)
                        try await tasks.reset(tracked: item)
                    } catch PatchTaskError.notFound, PollTaskError.notFound {
                        retryState = .notFound
                    } catch is CancellationError {
                        // noop
                    } catch {
                        retryState = .error(error)
                    }
                }
            }
            .keyboardShortcut(.defaultAction)
            
            Button(role: .cancel) {
                retryState = nil
            }
        } message: {
            Text("Discard the current summary and try again?")
        }
        .navigationTitle(item.title ?? String(localized: "Unnamed memory"))
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Open in browswer", systemImage: "arrow.up.forward.app") {
                        openURL(item.url)
                    }
                    Button("Retry", systemImage: "arrow.clockwise") {
                        retryState = .waitingForConfirmation
                    }
                    .disabled(tasks == nil)
                }
            }
    }
}

fileprivate enum RetryState {
    case waitingForConfirmation
    case error(any Error)
    case notFound
}
