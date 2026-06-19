import AsyncAlgorithms
import Common
import RealmSwift
import SwiftUI
import WebKit

@main struct SumalrApp: App {
    @State var realm = try! Realm(configuration: realmConfig)
    @State var rlamusClient: RlamusClient? = {
        guard let setUrl = UserDefaults.standard.string(forKey: "rlamusURL"),
              let endpoint = URL(string: setUrl) else {
            return nil
        }
        return RlamusClient(endpoint: endpoint)
    }()

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
                .sheet(isPresented: $showWebPreview) {
                    NavigationStack {
                        WebPreviewPage(webPage: $webPreviewPage) { @MainActor url, title in
                            let response = await errorHandler.runCatching { @MainActor in
                                let item = try await addMemory(url: url, client: await getRlamusClient())
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
                        .navigationDestination(isPresented: $showSetupSheet) {
                            SetupPage { client in
                                Task {
                                    await setupRlamus.send(client)
                                }
                            }
                            .navigationBarBackButtonHidden()
                        }
                    }
                }
                .sheet(isPresented: $showSetupSheet) {
                    SetupPage { client in
                        Task {
                            await setupRlamus.send(client)
                        }
                    }
                    .interactiveDismissDisabled()
                }
        }
        .environment(\.showWebPreview, $showWebPreview)
        .environment(\.rlamusClient, $rlamusClient)
        .environment(\.errorHandler, errorHandler)
        .environment(\.getRlamusClient, getRlamusClient)
        .environment(\.realm, realm)
        .onChange(of: rlamusClient?.endpoint, { _, newValue in
            UserDefaults.standard.setValue(newValue?.absoluteString, forKey: "rlamusURL")
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
                SetupPage { client in
                    Task {
                        await setupRlamus.send(client)
                    }
                }
                .interactiveDismissDisabled()
            }
        }
        .environment(\.showWebPreview, $showWebPreview)
        .environment(\.rlamusClient, $rlamusClient)
        .environment(\.errorHandler, errorHandler)
        .environment(\.getRlamusClient, getRlamusClient)
        .environment(\.realm, realm)
    }

    func getRlamusClient() async -> RlamusClient {
        if let rlamusClient {
            return rlamusClient
        }
        showSetupSheet = true
        for await client in setupRlamus {
            showSetupSheet = false
            rlamusClient = client
            return client
        }
        fatalError("Setup Rlamus channel closed without doing anything")
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
