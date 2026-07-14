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
                        .navigationDestination(item: $deepLink.memoryTaskID) { taskID in
                            if let memory = try? MemoryItem.fetch(taskID: taskID, modelContext: modelContext) {
                                MemoryPage(tasks?.tracked(memory: memory) ?? TrackedTask(memory: memory))
                            } else {
                                Text("Item not found")
                            }
                        }
                        .onAppear {
                            UNUserNotificationCenter.current().setBadgeCount(0)
                        }
                }
            }

            Tab("Topics", systemImage: "puzzlepiece.extension.fill", value: Page.topics) {
                NavigationStack {
                    TopicsPage()
                        .navigationTitle("Topics")
                        .navigationDestination(item: $deepLink.topicID) { topicID in
                            if let topic = modelContext.model(for: topicID) as? TopicItem {
                                TopicView(topic: topic)
                            } else {
                                Text("Item not found")
                            }
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
        .tabViewStyle(.sidebarAdaptable)
        #if os(iOS)
            .tabBarMinimizeBehavior(.onScrollDown)
        #endif
            .onOpenURL { url in
                handleDeepLink(DeepLink(url: url))
            }
            .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
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
        case topics
        case account
        case search
    }

    func handleDeepLink(_ value: DeepLink?) {
        let wait: DispatchTimeInterval
        switch value {
        case let .memory(taskID):
            if let memory = try? MemoryItem.fetch(taskID: taskID, modelContext: modelContext) {
                withAnimation {
                    libararyScrollPosition.scrollTo(id: memory.id)
                }
            }
            selectedTab = .library
            wait = selectedTab == .library ? .seconds(0) : .seconds(1)
        case .topic:
            selectedTab = .topics
            fallthrough
        default:
            wait = .seconds(0)
            break
        }
        DispatchQueue.main.schedule(after: .init(.now().advanced(by: wait))) {
            deepLink = value
        }
    }
}

extension Binding where Value == DeepLink? {
    var memoryTaskID: Binding<UUID?> {
        Binding<UUID?> {
            switch self.wrappedValue {
            case .memory(let taskID):
                taskID
            default:
                nil
            }
        } set: { newValue in
            if let newValue {
                self.wrappedValue = .memory(taskID: newValue)
            } else {
                self.wrappedValue = nil
            }
        }
    }
    
    var topicID: Binding<PersistentIdentifier?> {
        Binding<PersistentIdentifier?> {
            switch self.wrappedValue {
            case .topic(let id):
                id
            default:
                nil
            }
        } set: { newValue in
            if let newValue {
                self.wrappedValue = .topic(id: newValue)
            } else {
                self.wrappedValue = nil
            }
        }

    }
}

#Preview {
    ContentView()
}
