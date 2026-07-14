import Common
import CoreSpotlight
import Foundation
import Logging
import SwiftData
import SwiftUI

struct SearchPage: View {
    @Environment(\.tasks) var tasks
    @Environment(\.modelContext) var modelContext
    @Environment(\.openURL) var openURL
    @Environment(\.errorHandler) var errorHandler

    @State var candidates = [TrackedTask]()
    @State var suggestions = [CSUserQuery.Suggestion]()
    @State var buffer = ""
    @State var stableIndexShown = false

    let queryContext: CSUserQueryContext
    init() {
        queryContext = CSUserQueryContext()
        queryContext.fetchAttributes = ["title", "contentDescription"]
        queryContext.maxSuggestionCount = 10
        queryContext.enableRankedResults = true
        queryContext.disableSemanticSearch = false
    }

    var body: some View {
        List {
            ForEach(candidates) { candidate in
                Button {
                    openURL(DeepLink.memory(taskID: candidate.task.id).url)
                } label: {
                    CandidateItem(candidate)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay {
            if stableIndexShown {
                VStack {
                    Image(systemName: "magnifyingglass")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48)
                    Text("No Results")
                        .font(.title)
                    Text("If this is undesired, you may try \(try! AttributedString(markdown: "[invalidating index](in-app://invalidate-index)"))")
                        .environment(\.openURL, OpenURLAction(handler: { _ in
                            _ = errorHandler.runCatching {
                                try spotlightModelContainer.mainContext.delete(model: CSMemory.self)
                                withAnimation {
                                    stableIndexShown = false
                                }
                                Task {
                                    _ = await errorHandler.runCatching {
                                        _ = try await updateCSIndex(appMainIndex, dataModelContext: appModelContainer.mainContext, indexModelContext: spotlightModelContainer.mainContext, indexFetchDescriptor: FetchDescriptor<CSMemory>())
                                        stableIndexShown = !(try await search(query: buffer))
                                    }
                                }
                            }
                            return .handled
                        }))
                }
                .padding()
                .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
        .onAppear {
            CSUserQuery.prepare()
        }
        #if os(iOS)
        .searchable(text: $buffer, placement: .navigationBarDrawer, prompt: "Find a memory...")
        #else
        .searchable(text: $buffer, prompt: "Find a memory...")
        #endif
        .searchSuggestions {
            ForEach(suggestions) { suggestion in
                let title = String(suggestion.suggestion.localizedAttributedSuggestion.characters)
                Text(title)
                    .searchCompletion(title)
            }
        }
        .task {
            _ = await errorHandler.runCatching {
                _ = try await updateCSIndex(appMainIndex, dataModelContext: appModelContainer.mainContext, indexModelContext: spotlightModelContainer.mainContext, indexFetchDescriptor: FetchDescriptor<CSMemory>())
            }
        }
        .task(id: buffer) {
            do {
                try await Task.sleep(for: .seconds(0.3))
            } catch {
                return
            }
            do {
                stableIndexShown = !(try await search(query: buffer))
            } catch {
                appLogger.error("user query failed", error: error)
            }
        }
    }

    /// returns: is result not empty with reasonable query
    func search(query: String) async throws -> Bool {
        candidates = []
        suggestions = []
        if query.isEmpty {
            return true
        }

        let query = CSUserQuery(userQueryString: query, userQueryContext: queryContext)
        for try await element in query.responses {
            switch element {
            case let .item(item):
                if let url = URL(string: item.item.uniqueIdentifier),
                   let deepLink = DeepLink(url: url) {
                    switch deepLink {
                    case let .memory(taskID):
                        do {
                            if let memory = try MemoryItem.fetch(taskID: taskID, modelContext: modelContext) {
                                candidates.append(tasks?.tracked(memory: memory) ?? TrackedTask(memory: memory))
                                continue
                            } else {
                                appLogger.error("unknown task id")
                            }
                        } catch {
                            appLogger.error("failed to look up memory item", error: error)
                        }
                    default:
                        break
                    }
                }
                appLogger.warning("unknown response item")
            case let .suggestion(suggestion):
                suggestions.append(suggestion)
            @unknown default:
                fatalError()
            }
        }

        return !candidates.isEmpty || !suggestions.isEmpty
    }
    
    struct CandidateItem<D: ListItemDisplayProtocol>: View {
        let candidate: D
        
        init(_ candidate: D) {
            self.candidate = candidate
        }
        
        var body: some View {
            VStack(alignment: .leading) {
                if let title = candidate.title {
                    Text(title)
                } else {
                    Text("Unnamed memory")
                }
                if let summary = candidate.summary {
                    Group {
                        if let markdown = try? AttributedString(markdown: summary) {
                            Text(markdown)
                        } else {
                            Text(summary)
                        }
                    }
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
        }
    }
}
