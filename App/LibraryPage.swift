import AppIntents
import Common
import CoreSpotlight
import Foundation
import Logging
import SwiftData
import SwiftUI
import Transmission
import WebKit

struct LibraryPage: View {
    @Environment(\.errorHandler) var errorHandler
    @Environment(\.rlamusClient) var rlamusClient
    @Environment(\.modelContext) var modelContext
    @Environment(\.horizontalSizeClass) var windowSize
    @Environment(\.showWebPreview) var showWebPreview
    @Environment(\.tasks) var tasks
    @Environment(\.csModelContainer) var csModelContainer
    #if os(macOS)
        @Environment(\.openWindow) var openWindow
    #endif

    @Query(sort: [SortDescriptor<MemoryItem>(\.creation, order: .reverse)], animation: .default) var memories: [MemoryItem]
    @Binding var scrollPosition: ScrollPosition

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
                            TaskItemView(tasks?.tracked(memory: memory) ?? TrackedTask(memory: memory))
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
                            MemoryPage(tasks?.tracked(memory: memory) ?? TrackedTask(memory: memory))
                        } label: {
                            TaskItemView(tasks?.tracked(memory: memory) ?? TrackedTask(memory: memory))
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
            .scrollTargetLayout()
            .animation(.default, value: memories)
            .swipeActionsContainer()
            .padding()
        }
        .scrollPosition($scrollPosition)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") {
                    showWebPreview.wrappedValue = !showWebPreview.wrappedValue
                }
            }
        }
    }

    private func remove(memory: MemoryItem) {
        modelContext.delete(memory)
        Task {
            do {
                try await appMainIndex.deleteSearchableItems(withIdentifiers: [MemoryEntity(memory).id])
            } catch {
                appLogger.error("failed to remove from Spotlight index", error: error)
            }
        }
    }
}

struct TaskItemView: View {
    let item: TrackedTask
    var isLoading: Bool {
        item.summary == nil
    }

    init(_ item: TrackedTask) {
        self.item = item
    }

    var body: some View {
        VStack(alignment: .leading) {
            if isLoading {
                ProgressView(value: Float(item.progress), total: 3)
                    .frame(maxWidth: .infinity)
                    .animation(.default, value: isLoading)
            }
            if let title = item.title {
                Text(title)
                    .font(.title3)
                    .textSelection(.enabled)
                    .padding(.bottom, 4)
            }
            if let summary = item.summary {
                Group {
                    if let markdown = try? NSAttributedString(markdown: summary) {
                        Text("\(markdown)")
                    } else {
                        Text(summary)
                    }
                }
                .lineLimit(3)
                .disabled(true)
            }
            if let errorMessage = item.error?.localizedDescription {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else if case let .failed(message) = item.value.state {
                Text(message)
                    .foregroundStyle(.red)
            }
            Spacer()
            Link(destination: item.url) {
                HStack {
                    Image(systemName: "safari")
                    Text(item.url.absoluteString)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
    }
}

#Preview {
    VStack {
        TaskItemView(TrackedTask(value: RlamusTask(id: UUID(), url: URL(string: "https://example.com")!), initialTitle: "Some page", creation: .now))
            .padding()

        TaskItemView(TrackedTask(value: RlamusTask(id: UUID(), url: URL(string: "https://example.com")!, state: .scraping), initialTitle: "Some page", creation: .now))
            .padding()

        TaskItemView(TrackedTask(value: RlamusTask(id: UUID(), url: URL(string: "https://example.com")!, state: .done(title: "Some page", summary: Array(repeating: "Example domain is for demostration purpose only and shouldn't be used in production.", count: 50).joined(separator: "\n"))), creation: .now))
            .padding()
    }
}
