import Common
import SwiftData
import SwiftUI
import Logging

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.tasks) var tasks

    @State var deepLink: DeepLink? = nil
    @State var selectedTab: Page = .library

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: Page.library) {
                NavigationStack {
                    LibraryPage()
                        .onChange(of: tasks, { oldValue, newValue in
                            if newValue == nil {
                                appLogger.warning("nil tasks")
                            } else {
                                appLogger.warning("present tasks")
                            }
                        })
                        .navigationTitle("Sumalr")
                        .navigationDestination(item: $deepLink) { dl in
                            switch dl {
                            case let .memory(taskID):
                                if let memory = try? MemoryItem.fetch(taskID: taskID, modelContext: modelContext) {
                                    MemoryPage(tasks?.tracked(memory: memory) ?? TrackedTask(memory: memory))
                                } else {
                                    MemoryPage()
                                }
                            }
                        }
                }
            } label: {
                Button("Library", systemImage: "books.vertical") {
                }
            }

            Tab(value: Page.account) {
                NavigationStack {
                    AccountPage()
                        .navigationTitle("Sumalr")
                }
            } label: {
                Button("Account", systemImage: "person.circle") {
                }
            }
        }
        .onOpenURL { url in
            deepLink = DeepLink(url: url)
            if case .memory = deepLink {
                selectedTab = .library
            }
        }
    }

    enum Page: Hashable {
        case library
        case account
    }
}

#Preview {
    ContentView()
}
