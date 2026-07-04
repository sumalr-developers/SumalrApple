import Foundation
import SwiftData
import SwiftUI
internal import UniformTypeIdentifiers

public struct ShareSheetView: View {
    @Environment(\.dismissSharesheet) var dismiss
    @Environment(\.modelContext) var modelContext

    @State var rlamusClient: RlamusClient? = getRlamusFrom(userDefaults: .appGroup)
    @State var showSetupPage = false
    @State var error: (any Error)? = nil
    @State var completedCount = 0
    @State var state: ShareState = .creating
    @State var closingCountdown = 10

    let sharedItems: [NSItemProvider]
    public init(_ sharedItems: [NSItemProvider]) {
        self.sharedItems = sharedItems
    }

    public var body: some View {
        #if os(macOS)
            VStack {
                switch state {
                case .creating:
                    Spacer()
                    creatingView
                    Spacer()
                    HStack {
                        Spacer()
                        Button("Cancel") {
                            dismiss(.canceled(CancellationError()))
                        }
                    }
                    .padding()
                case .completed:
                    CompletedView()
                }
            }
            .alert(error: $error) {
                Button("Cancel", role: .cancel) {
                    if let error {
                        dismiss(.canceled(error))
                    } else {
                        dismiss(.ok)
                    }
                }
            }
        #else
            NavigationStack {
                Group {
                    switch state {
                    case .creating:
                        creatingView
                    case .completed:
                        CompletedView()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") {
                            dismiss(.canceled(CancellationError()))
                        }
                    }
                }
            }
            .alert(error: $error) {
                Button("Cancel", role: .cancel) {
                    if let error {
                        dismiss(.canceled(error))
                    } else {
                        dismiss(.ok)
                    }
                }
            }
        #endif
    }

    var creatingView: some View {
        CreatingView(progress: Float(completedCount) / Float(sharedItems.count))
            .task {
                guard let rlamusClient else {
                    showSetupPage = true
                    return
                }

                do {
                    let deviceInfo: NotificationRegistration? =
                        if let token = getDeviceToken(from: .appGroup),
                        let topic = Bundle.main.bundleIdentifier {
                        NotificationRegistration(deviceToken: token, topic: String(topic[topic.startIndex ..< topic.lastIndex(of: ".")!]))
                    } else {
                        nil
                    }
                    for item in sharedItems {
                        let url = try await loadAsURL(item)
                        async let itemTask = try addMemory(url: url, client: rlamusClient, registerForNotifications: deviceInfo)
                        async let titleTask = try? getWebPageTitle(url: url)
                        let (item, title) = try await (itemTask, titleTask)
                        if let title {
                            item.title = title
                        }
                        modelContext.insert(item)
                        try modelContext.save()
                        completedCount += 1
                    }
                    state = .completed
                } catch {
                    print("\(error)")
                    self.error = error
                }
            }
            .navigationDestination(isPresented: $showSetupPage) {
                SetupPage { newClient in
                    rlamusClient = newClient
                    setRlamusTo(userDefaults: .appGroup, endpoint: newClient.endpoint)
                    showSetupPage = false
                }
            }
    }
}

func loadAsURL(_ item: NSItemProvider) async throws -> URL {
    if let url = try? await item.loadObject(ofClass: NSURL.self) as URL? {
        return url
    }

    if item.registeredContentTypes.contains(.plainText) {
        if let data = try? await item.loadDataRepresentation(for: .plainText),
           let str = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: data),
           let url = URL(string: str as String) {
            return url
        }
    }

    throw UnsupportedShareTypeError()
}

extension NSString: @unchecked @retroactive Sendable {}

extension NSItemProvider {
    func loadObject<T>(ofClass: T.Type) async throws -> T
        where T: NSItemProviderReading & Sendable {
        try await withCheckedThrowingContinuation { continutation in
            self.loadObject(ofClass: ofClass as NSItemProviderReading.Type) { value, error in
                if let error {
                    continutation.resume(throwing: error)
                } else {
                    continutation.resume(returning: value! as! T)
                }
            }
        }
    }

    func loadDataRepresentation(for type: UTType) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            _ = self.loadDataRepresentation(for: type) { value, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: value!)
                }
            }
        }
    }
}

struct UnsupportedShareTypeError: Error, LocalizedError {
    var errorDescription: String? {
        String(localized: "This type of shared item is not supported")
    }
}

enum ShareState {
    case creating
    case completed
}

public enum SharesheetDismissal {
    case ok
    case canceled(any Error)
}

extension EnvironmentValues {
    @Entry public var dismissSharesheet: (_ dismissal: SharesheetDismissal) -> Void = { _ in }
}

fileprivate struct FullWidthButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                wrappedLabel
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
        } else {
            Button(action: action) {
                wrappedLabel
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
    }

    var wrappedLabel: some View {
        label()
            .bold()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }
}

fileprivate struct CreatingView<P: BinaryFloatingPoint>: View {
    let progress: P

    var body: some View {
        Group {
            if progress.isZero {
                ProgressView("Creating tasks remotely...")
            } else {
                ProgressView("Creating tasks remotely...", value: progress)
            }
        }
        .progressViewStyle(.linear)
        .padding()
    }
}

fileprivate struct CompletedView: View {
    @Environment(\.dismissSharesheet) var dismiss
    @State var animating = true

    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "checkmark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48)
                .symbolEffect(.drawOn, isActive: animating)
                .foregroundStyle(.green)
            VStack(alignment: .leading) {
                Text("Tasks submitted")
                    .font(.headline)
                Text("You can track generation progress in the main app.")
            }
            .padding(.horizontal)
            Spacer()
            FullWidthButton {
                dismiss(.ok)
            } label: {
                Text("Closing in \(Text(timerInterval: Date.now ... Date(timeInterval: 10, since: .now)))")
                    .task {
                        try? await Task.sleep(for: .seconds(10))
                        dismiss(.ok)
                    }
            }
            .tint(.clear)
            .padding()
        }
        .onAppear {
            animating = false
        }
    }
}

#Preview {
    HStack {
        CreatingView(progress: 0.5)
        CompletedView()
    }
}
