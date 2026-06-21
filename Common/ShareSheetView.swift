import Foundation
import SwiftUI
import SwiftData

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
        NavigationStack {
            Group {
                switch state {
                case .creating:
                    creatingView
                case .completed:
                    CompletedView()
                }
            }
            .alert(error: $error) {
                Button("Cancel", role: .cancel) {
                    error = nil
                    dismiss()
                }
            }
        }
    }

    var creatingView: some View {
        CreatingView(progress: Float(completedCount) / Float(sharedItems.count))
            .task {
                guard let rlamusClient else {
                    showSetupPage = true
                    return
                }

                do {
                    for item in sharedItems {
                        let url = try await item.loadObject(ofType: URL.self)
                        async let itemTask = try addMemory(url: url, client: rlamusClient)
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

enum ShareState {
    case creating
    case completed
}

extension EnvironmentValues {
    @Entry public var dismissSharesheet: () -> Void = {}
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
        ProgressView(value: progress) {
            Text("Creating tasks remotely...")
        }
        .padding()
    }
}

fileprivate struct CompletedView: View {
    @Environment(\.dismissSharesheet) var dismiss
    
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "checkmark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48)
                .foregroundStyle(.green)
            VStack(alignment: .leading) {
                Text("Tasks submitted")
                    .font(.headline)
                Text("You can track generation progress in the main app.")
            }
            Spacer()
            FullWidthButton {
                dismiss()
            } label: {
                Text("Closing in \(Text(timerInterval: Date.now ... Date(timeInterval: 10, since: .now)))")
                    .task {
                        try? await Task.sleep(for: .seconds(10))
                        dismiss()
                    }
            }
            .tint(.clear)
            .padding()
        }
    }
}

#Preview {
    HStack {
        CreatingView(progress: 0.5)
        CompletedView()
    }
}
