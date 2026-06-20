import AsyncAlgorithms
import Common
import CoreData
import Foundation
import SwiftData
import SwiftUI
import WebKit

@main struct SumalrApp: App {
    @State var setupRlamus = AsyncChannel<RlamusClient>()
    @State var rlamusClient: RlamusClient? = getRlamusFrom(userDefaults: .appGroup)
    @State var showSetupSheet = false
    @State var showWebPreview = false

    var body: some Scene {
        Group {
            MainScene(showSetupSheet: $showSetupSheet, setupRlamus: setupRlamus)
            MemoryScene(showSetupSheet: $showSetupSheet, setupRlamus: setupRlamus)
        }
        .environment(\.showWebPreview, $showWebPreview)
        .environment(\.rlamusClient, $rlamusClient)
        .environment(\.getRlamusClient, getRlamusClient)
        .modelContainer(appModelContainer)
    }

    func dependencyInjected<W: Scene>(_ wg: W) -> some Scene {
        wg
    }

    func getRlamusClient() async throws (CancellationError) -> RlamusClient {
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

fileprivate struct MainScene: Scene {
    @Environment(\.getRlamusClient) var getRlamusClient
    @Environment(\.showWebPreview) var showWebPreview
    @Environment(\.rlamusClient) var rlamusClient
    @Environment(\.modelContext) var modelContext

    @Binding var showSetupSheet: Bool
    let setupRlamus: AsyncChannel<RlamusClient>

    @State var errorHandler = ErrorHandler()
    @State var webPreviewPage = WebPage()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .alert(error: $errorHandler.current) {
                    Button(role: .cancel) {
                        errorHandler.current = nil
                    }
                }
                .sheet(isPresented: showWebPreview, onDismiss: {
                    showSetupSheet = false
                }) {
                    NavigationStack {
                        WebPreviewPage(webPage: $webPreviewPage) { @MainActor url, title in
                            let client: RlamusClient
                            do throws (CancellationError) {
                                client = try await getRlamusClient()
                            } catch {
                                return
                            }

                            let response = await errorHandler.runCatching { @MainActor in
                                let item = try await addMemory(url: url, client: client)
                                item.title = title.isEmpty ? nil : title
                                modelContext.insert(item)
                                try modelContext.save()
                                return item
                            }
                            if case .success = response {
                                showWebPreview.wrappedValue = false
                            }
                        }
                        .frame(minHeight: 400)
                        .toolbar {
                            ToolbarItem(placement: .navigation) {
                                Button("Close", systemImage: "xmark") {
                                    showWebPreview.wrappedValue = false
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
        .onChange(of: rlamusClient.wrappedValue?.endpoint) { _, newValue in
            setRlamusTo(userDefaults: .appGroup, endpoint: newValue)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New from URL") {
                    showWebPreview.wrappedValue = true
                }
                .keyboardShortcut("N")
            }
        }
        .environment(\.errorHandler, errorHandler)
    }
}

fileprivate struct MemoryScene: Scene {
    @Environment(\.modelContext) var modelContext

    @Binding var showSetupSheet: Bool
    let setupRlamus: AsyncChannel<RlamusClient>

    var body: some Scene {
        WindowGroup(id: "memory", for: OpenMemory.self) { $openMemory in
            Group {
                if let openMemory,
                   let memory: MemoryItem = modelContext.registeredModel(for: openMemory.pk) {
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
    }
}
