import Common
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    
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
                                MemoryPage(try? MemoryItem.fetch(taskID: taskID, modelContext: modelContext))
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
