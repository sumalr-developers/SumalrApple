import Common
import Foundation
import Logging
import SwiftData
import SwiftUI
import Textual
import Transmission
import WebKit
import CoreSpotlight
import AppIntents

struct LibraryPage: View {
    @Environment(\.errorHandler) var errorHandler
    @Environment(\.rlamusClient) var rlamusClient
    @Environment(\.modelContext) var modelContext
    @Environment(\.horizontalSizeClass) var windowSize
    @Environment(\.showWebPreview) var showWebPreview
    #if os(macOS)
        @Environment(\.openWindow) var openWindow
    #endif

    @Query var memories: [MemoryItem]

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
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 12).foregroundStyle(.background.secondary))
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                remove(memory: memory)
                            }
                        }
                    #elseif os(iOS)
                        DestinationLink(transition: .zoom) {
                            MemoryPage(memory)
                        } label: {
                            MemoryItemView(memory)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 12).foregroundStyle(.background.secondary))
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                remove(memory: memory)
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
        .onChange(of: memories) {
            MemoryShortcutProvider.updateAppShortcutParameters()
        }
    }
    
    private func remove(memory: MemoryItem) {
        modelContext.delete(memory)
        MemoryShortcutProvider.updateAppShortcutParameters()
    }
}

struct MemoryItemView: View {
    @Environment(\.getRlamusClient) var getRlamusClient
    @Environment(\.errorHandler) var errorHandler
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.modelContext) var modelContext

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
        let itemId: PersistentIdentifier
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
        .task(id: ItemIDScenePhaseTuple(scene: scenePhase, itemId: item.persistentModelID)) {
            if item.summary != nil || scenePhase != .active {
                return
            }

            do {
                let client: RlamusClient
                do throws (CancellationError) {
                    client = try await getRlamusClient()
                } catch {
                    return
                }

                for try await state in item.streamTaskState(client: client) {
                    switch state {
                    case .`init`:
                        item.summary = nil
                        try modelContext.save()
                        progress = 0
                    case .scraping:
                        progress = 1
                    case .summarizing:
                        progress = 2
                    case let .done(summary):
                        item.summary = summary
                        try modelContext.save()
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
                        MemoryShortcutProvider.updateAppShortcutParameters()
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
            let r = MemoryItem(url: "https://example.com", taskID: UUID())
            r.summary = "Example domain is for demostration purpose only and shouldn't be used in production."
            r.title = "Some page"
            return r
        }())
            .padding()

        MemoryItemView({
            let r = MemoryItem(url: "https://example.com", taskID: UUID())
            r.summary = Array(repeating: "Example domain is for demostration purpose only and shouldn't be used in production.", count: 50).joined(separator: "\n")
            r.title = "Some page"
            return r
        }())
            .padding()
    }
}
