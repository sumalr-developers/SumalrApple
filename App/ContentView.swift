import Common
import RealmSwift
import SwiftUI
import WebKit

@main struct SumalrApp: App {
    @Environment(\.realm) var realm

    @State var showWebPreview = false
    @State var webPreviewPage = WebPage()
    @State var rlamusClient: RlamusClient? = {
        guard let setUrl = UserDefaults.standard.string(forKey: "rlamusURL"),
              let endpoint = URL(string: setUrl) else {
            return nil
        }
        return RlamusClient(endpoint: endpoint)
    }()

    @State var errorHandler = ErrorHandler()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.showWebPreview, $showWebPreview)
                .environment(\.rlamusClient, $rlamusClient)
                .environment(\.errorHandler, errorHandler)
                .alert(error: $errorHandler.current) {
                    Button(role: .cancel) {
                        errorHandler.current = nil
                    }
                }
                .sheet(isPresented: $showWebPreview) {
                    NavigationStack {
                        WebPreviewPage(webPage: $webPreviewPage) { @MainActor url, title in
                            let response = await errorHandler.runCatching { @MainActor in
                                let item = try await addMemory(url: url, client: rlamusClient!)
                                item.title = title
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
                    }
                }
        }
        .onChange(of: rlamusClient?.endpoint, { oldValue, newValue in
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
