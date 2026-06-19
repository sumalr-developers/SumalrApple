import AsyncAlgorithms
import Common
import RealmSwift
import SwiftUI
import WebKit

@main struct SumalrApp: App {
    @State var realm = try! Realm(configuration: realmConfig)
    @State var rlamusClient: RlamusClient? = getRlamusFrom(userDefaults: .appGroup)

    @State var showWebPreview = false
    @State var webPreviewPage = WebPage()
    @State var errorHandler = ErrorHandler()

    @State var setupRlamus = AsyncChannel<RlamusClient>()
    @State var showSetupSheet = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .alert(error: $errorHandler.current) {
                    Button(role: .cancel) {
                        errorHandler.current = nil
                    }
                }
                .sheet(isPresented: $showWebPreview, onDismiss: {
                    showSetupSheet = false
                }) {
                    NavigationStack {
                        WebPreviewPage(webPage: $webPreviewPage) { @MainActor url, title in
                            let client: RlamusClient
                            do throws(CancellationError) {
                                client = try await getRlamusClient()
                            } catch {
                                return
                            }
                            
                            let response = await errorHandler.runCatching { @MainActor in
                                let item = try await addMemory(url: url, client: client)
                                item.title = title.isEmpty ? nil : title
                                try realm.write {
                                    realm.add(item)
                                }
                                return item
                            }
                            if case .success = response {
                                showWebPreview = false
                            }
                        }
                        .frame(minHeight: 400)
                        .toolbar {
                            ToolbarItem(placement: .navigation) {
                                Button("Close", systemImage: "xmark") {
                                    showWebPreview = false
                                }
                            }
                        }
                        .sheet(isPresented: $showSetupSheet) {
                            setupRlamus.finish()
                        } content: {
                            SetupPage { client in
                                Task {
                                    await setupRlamus.send(client)
                                }
                            }
                        }
                    }
                }
                .sheet(isPresented: $showSetupSheet) {
                    NavigationStack {
                        SetupPage { client in
                            Task {
                                await setupRlamus.send(client)
                            }
                        }
                        .interactiveDismissDisabled()
                    }
                }
        }
        .environment(\.showWebPreview, $showWebPreview)
        .environment(\.rlamusClient, $rlamusClient)
        .environment(\.errorHandler, errorHandler)
        .environment(\.getRlamusClient, getRlamusClient)
        .environment(\.realm, realm)
        .onChange(of: rlamusClient?.endpoint, { _, newValue in
            setRlamusTo(userDefaults: .appGroup, endpoint: newValue)
        })
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New from URL") {
                    showWebPreview = true
                }
                .keyboardShortcut("N")
            }
        }

        WindowGroup(id: "memory", for: OpenMemory.self) { $openMemory in
            Group {
                if let openMemory,
                   let memory = realm.object(ofType: MemoryItem.self, forPrimaryKey: openMemory.pk) {
                    MemoryPage(memory)
                } else {
                    MemoryPage()
                }
            }
            .sheet(isPresented: $showSetupSheet) {
                NavigationStack {
                    SetupPage { client in
                        Task {
                            await setupRlamus.send(client)
                        }
                    }
                    .interactiveDismissDisabled()
                }
            }
        }
        .environment(\.showWebPreview, $showWebPreview)
        .environment(\.rlamusClient, $rlamusClient)
        .environment(\.errorHandler, errorHandler)
        .environment(\.getRlamusClient, getRlamusClient)
        .environment(\.realm, realm)
    }

    func getRlamusClient() async throws(CancellationError) -> RlamusClient {
        if let rlamusClient {
            return rlamusClient
        }
        setupRlamus = AsyncChannel()
        showSetupSheet = true
        for await client in setupRlamus {
            showSetupSheet = false
            rlamusClient = client
            return client
        }
        throw CancellationError()
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Library", systemImage: "books.vertical") {
                NavigationStack {
                    LibraryPage()
                        .navigationTitle("Sumalr")
                }
            }

            Tab("Account", systemImage: "person.circle") {
                NavigationStack {
                    AccountPage()
                        .navigationTitle("Sumalr")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
