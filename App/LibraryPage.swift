import Common
import Foundation
import Logging
import Realm
import RealmSwift
import SwiftUI
import Textual
import WebKit

struct LibraryPage: View {
    @Environment(\.errorHandler) var errorHandler
    @Environment(\.rlamusClient) var rlamusClient
    @Environment(\.realm) var realm
    @Environment(\.horizontalSizeClass) var windowSize
    @Environment(\.showWebPreview) var showWebPreview

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
                    MemoryItemView(memory)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).foregroundStyle(.background.secondary))
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                $memories.remove(memory)
                            }
                        }
                }
            }
            .animation(.default, value: memories)
            .swipeActionsContainer()
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") {
                    showWebPreview.wrappedValue = true
                }
            }
        }
    }
}

struct MemoryItemView: View {
    @Environment(\.rlamusClient) var rlamusClient
    @Environment(\.errorHandler) var errorHandler
    @Environment(\.realm) var realm

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

    var body: some View {
        VStack(alignment: .leading) {
            if isLoading {
                ProgressView(value: Float(progress), total: 3)
                    .frame(maxWidth: .infinity)
            }
            if let title = item.title {
                Text(title)
                    .font(.title3)
                    .textSelection(.enabled)
                    .padding(.bottom, 4)
            }
            if let summary = item.summary {
                StructuredText(markdown: summary)
                    .textual.textSelection(.enabled)
            }
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
            Link(destination: URL(string: item.url)!) {
                HStack {
                    Image(systemName: "safari")
                    Text(item.url)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .task(id: item.id) {
            if item.summary != nil {
                return
            }

            do {
                guard let client = rlamusClient.wrappedValue else {
                    return
                }
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
    MemoryItemView({
        let r = MemoryItem()
        r.summary = "Example domain is for demostration purpose only and shouldn't be used in production."
        r.title = "Some page"
        r.url = "https://example.com"
        return r
    }())
        .padding()
}
