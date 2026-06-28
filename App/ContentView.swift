import Common
import SwiftUI
import SwiftData

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
                        .navigationTitle("Sumalr")
                        .navigationDestination(item: $deepLink) { dl in
                            switch dl {
                            case .memory(let taskID):
                                if let memory = try? MemoryItem.fetch(taskID: taskID, modelContext: modelContext) {
                                    MemoryPage(tasks.tracked(memory: memory))
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
