import Common
import CoreSpotlight
import Logging
import SwiftData
import SwiftUI
import UserNotifications
internal import Combine

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.tasks) var tasks

    @State var deepLink: DeepLink? = nil
    @State var selectedTab: Page = .library
    @State var libararyScrollPosition: ScrollPosition = .init()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Library", systemImage: "books.vertical", value: Page.library) {
                NavigationStack {
                    LibraryPage(scrollPosition: $libararyScrollPosition)
                        .onChange(of: tasks, { _, newValue in
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
            }

            Tab("Account", systemImage: "person.circle", value: Page.account) {
                NavigationStack {
                    AccountPage()
                        .navigationTitle("Sumalr")
                }
            }

            Tab(value: Page.search, role: .search) {
                NavigationStack {
                    SearchPage()
                        .navigationTitle("Sumalr")
                }
            }
        }
        .tabViewSearchActivation(.searchTabSelection)
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
        case search
    }

    func handleDeepLink(_ value: DeepLink?) {
        let wait: DispatchTimeInterval = selectedTab == .library ? .never : .seconds(1)
        switch value {
        case let .memory(taskID):
            if let memory = try? MemoryItem.fetch(taskID: taskID, modelContext: modelContext) {
                withAnimation {
                    libararyScrollPosition.scrollTo(id: memory.id)
                }
            }
            selectedTab = .library
        default:
            break
        }
        DispatchQueue.main.schedule(after: .init(.now().advanced(by: wait))) {
            deepLink = value
        }
    }
}

#Preview {
    ContentView()
}
