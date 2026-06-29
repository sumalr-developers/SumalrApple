import AppIntents
import AsyncAlgorithms
import Common
import CoreData
import Foundation
import Logging
import SwiftData
import SwiftUI
import WebKit

@main struct SumalrApp: App {
    @Environment(\.scenePhase) var scenePhase
    #if os(iOS)
        @UIApplicationDelegateAdaptor(UIApp.self) var appDelegate
    #elseif os(macOS)
        @NSApplicationDelegateAdaptor(NSApp.self) var appDelegate
    #endif

    @State var setupRlamus = AsyncChannel<RlamusClient>()
    @State var rlamusClient: RlamusClient? = getRlamusFrom(userDefaults: .appGroup)
    @State var showSetupSheet = false
    @State var showWebPreview = false
    @State var taskTracker: TaskTracker? = nil

    init() {
        MemoryShortcutProvider.updateAppShortcutParameters()
    }

    var body: some Scene {
        Group {
            MainScene(showSetupSheet: $showSetupSheet, setupRlamus: setupRlamus)
                .handlesExternalEvents(matching: ["*"])
            MemoryScene(showSetupSheet: $showSetupSheet, setupRlamus: setupRlamus)
        }
        .environment(\.showWebPreview, $showWebPreview)
        .environment(\.rlamusClient, $rlamusClient)
        .environment(\.getRlamusClient, getRlamusClient)
        .environment(\.deviceToken, appDelegate.deviceToken)
        .environment(\.tasks, {
            if let taskTracker {
                return taskTracker
            }
            let tt = TaskTracker(getClient: getRlamusClient, modelContext: appModelContainer.mainContext)
            taskTracker = tt
            return tt
        }())
        .modelContainer(appModelContainer)
        .onChange(of: scenePhase) { _, newValue in
            Task {
                switch newValue {
                case .active:
                    do {
                        try await taskTracker?.resumeAll()
                    } catch {
                        appLogger.error("unable to resume task tracker", error: error)
                    }
                default:
                    await taskTracker?.pauseAll()
                }
            }
        }
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
    @Environment(\.deviceToken) var deviceToken

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
                                let item = if let deviceToken, let topic = Bundle.main.bundleIdentifier {
                                    try await addMemory(url: url, client: client,
                                                        registerForNotifications: .init(deviceToken: deviceToken, topic: topic))
                                } else {
                                    try await addMemory(url: url, client: client)
                                }
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
    @Environment(\.tasks) var tasks

    @Binding var showSetupSheet: Bool
    let setupRlamus: AsyncChannel<RlamusClient>

    var body: some Scene {
        WindowGroup(id: "memory", for: OpenMemory.self) { $openMemory in
            Group {
                if let openMemory,
                   let memory: MemoryItem = modelContext.registeredModel(for: openMemory.pk) {
                    MemoryPage(tasks.tracked(memory: memory))
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
