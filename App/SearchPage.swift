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

    @State var candidates = [TrackedTask]()
    @State var suggestions = [CSUserQuery.Suggestion]()
    @State var buffer = ""
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
                    openURL(DeepLink.memory(taskID: candidate.value.id).url)
                } label: {
                    VStack(alignment: .leading) {
                        if let title = candidate.title {
                            Text(title)
                        } else {
                            Text("Unnamed memory")
                        }
                        if let summary = candidate.summary {
                            Text(summary)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .onAppear {
            CSUserQuery.prepare()
        }
        .searchable(text: $buffer, placement: .navigationBarDrawer, prompt: "Find a memory...")
        .searchSuggestions {
            ForEach(suggestions) { suggestion in
                let title = String(suggestion.suggestion.localizedAttributedSuggestion.characters)
                Text(title)
                    .searchCompletion(title)
            }
        }
        .task(id: buffer) {
            do {
                try await Task.sleep(for: .seconds(0.3))
            } catch {
                return
            }
            candidates = []
            suggestions = []
            if buffer.isEmpty {
                return
            }

            let query = CSUserQuery(userQueryString: buffer, userQueryContext: queryContext)
            do {
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
                                    } else {
                                        appLogger.error("unknown task id")
                                    }
                                } catch {
                                    appLogger.error("failed to look up memory item", error: error)
                                }
                            }
                        } else {
                            appLogger.warning("unknown response item")
                        }
                    case let .suggestion(suggestion):
                        self.suggestions.append(suggestion)
                    @unknown default:
                        fatalError()
                    }
                }
            } catch {
                appLogger.error("user query failed", error: error)
            }
        }
    }
}
