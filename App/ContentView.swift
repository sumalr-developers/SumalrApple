import Common
import SwiftData
import SwiftUI
import Logging
import CoreSpotlight

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
                        .onAppear {
                            UNUserNotificationCenter.current().setBadgeCount(0)
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
            handleDeepLink(DeepLink(url: url))
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            if let urlString = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
               let url = URL(string: urlString),
               let deepLink = DeepLink(url: url) {
                handleDeepLink(deepLink)
            }
        }
    }

    enum Page: Hashable {
        case library
        case account
    }
    
    func handleDeepLink(_ value: DeepLink?) {
        switch value {
        case .memory:
            selectedTab = .library
        default:
            break
        }
        deepLink = value
    }
}

#Preview {
    ContentView()
}
