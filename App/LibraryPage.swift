import Common
import Foundation
import Logging
import Realm
import RealmSwift
import SwiftUI
import Textual
import Transmission
import WebKit

struct LibraryPage: View {
    @Environment(\.errorHandler) var errorHandler
    @Environment(\.rlamusClient) var rlamusClient
    @Environment(\.realm) var realm
    @Environment(\.horizontalSizeClass) var windowSize
    @Environment(\.showWebPreview) var showWebPreview
    #if os(macOS)
        @Environment(\.openWindow) var openWindow
    #endif

    @ObservedResults(MemoryItem.self) var memories

    var columns: [GridItem] {
        let columns: Int
        switch windowSize ?? .compact {
        case .compact:
            columns = 1
        case .regular:
            columns = 3
        default:
            columns = 1
        }
        return Array(repeating: GridItem(.flexible(), alignment: .top), count: columns)
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: columns) {
                ForEach(memories) { memory in
                    #if os(macOS)
                        Button {
                            openWindow(value: OpenMemory(memory))
                        } label: {
                            MemoryItemView(memory)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 12).foregroundStyle(.background.secondary))
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                $memories.remove(memory)
                            }
                        }
                    #elseif os(iOS)
                        DestinationLink(transition: .zoom) {
                            MemoryPage(memory)
                        } label: {
                            MemoryItemView(memory)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 12).foregroundStyle(.background.secondary))
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                $memories.remove(memory)
                            }
                        }
                    #endif
                }
            }
            .animation(.default, value: memories)
            .swipeActionsContainer()
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") {
                    showWebPreview.wrappedValue = !showWebPreview.wrappedValue
                }
            }
        }
    }
}

struct MemoryItemView: View {
    @Environment(\.getRlamusClient) var getRlamusClient
    @Environment(\.errorHandler) var errorHandler
    @Environment(\.realm) var realm
    @Environment(\.scenePhase) var scenePhase

    let item: MemoryItem
    @State var isLoading: Bool
    @State var progress: Int
    @State var errorMessage: String?

    init(_ item: MemoryItem) {
        self.item = item
        isLoading = item.summary == nil
        progress = 0
        errorMessage = nil
    }

    private struct ItemIDScenePhaseTuple: Equatable {
        let scene: ScenePhase
        let itemId: UInt64
    }

    var body: some View {
        VStack(alignment: .leading) {
            if isLoading {
                ProgressView(value: Float(progress), total: 3)
                    .frame(maxWidth: .infinity)
                    .animation(.default, value: progress)
            }
            if let title = item.title {
                Text(title)
                    .font(.title3)
                    .textSelection(.enabled)
                    .padding(.bottom, 4)
            }
            if let summary = item.summary {
                StructuredText(markdown: {
                    if summary.count > 150 {
                        summary.prefix(150).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
                    } else {
                        summary
                    }
                }())
                    .disabled(true)
            }
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
            Spacer()
            Link(destination: URL(string: item.url)!) {
                HStack {
                    Image(systemName: "safari")
                    Text(item.url)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .task(id: ItemIDScenePhaseTuple(scene: scenePhase, itemId: item.id)) {
            if item.summary != nil || scenePhase != .active {
                return
            }

            do {
                let client = await getRlamusClient()
                for try await state in item.streamTaskState(client: client) {
                    switch state {
                    case .`init`:
                        guard let thawed = item.thaw() else {
                            break
                        }
                        try? realm.write {
                            thawed.summary = nil
                        }
                        progress = 0
                    case .scraping:
                        progress = 1
                    case .summarizing:
                        progress = 2
                    case let .done(summary):
                        guard let thawed = item.thaw() else {
                            break
                        }
                        try? realm.write {
                            thawed.summary = summary
                        }
                        progress = 3
                        isLoading = false
                        do {
                            // delete from server for privacy
                            try await client.deleteTask(id: item.taskID)
                        } catch {
                            appLogger.info("failed to delete after pull", error: error, metadata: ["taskID": .string(item.taskID.uuidString)])
                        }
                        break
                    case let .failed(reason):
                        progress = 3
                        errorMessage = reason
                        isLoading = false
                        break
                    }

                    if !isLoading {
                        break
                    }
                }
            } catch {
                appLogger.critical("unable to update memory", error: error, metadata: ["taskID": .string(item.taskID.uuidString)])
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

#Preview {
    VStack {
        MemoryItemView({
            let r = MemoryItem()
            r.summary = "Example domain is for demostration purpose only and shouldn't be used in production."
            r.title = "Some page"
            r.url = "https://example.com"
            return r
        }())
            .padding()

        MemoryItemView({
            let r = MemoryItem()
            r.summary = Array(repeating: "Example domain is for demostration purpose only and shouldn't be used in production.", count: 50).joined(separator: "\n")
            r.title = "Some page"
            r.url = "https://example.com"
            return r
        }())
            .padding()
    }
}
