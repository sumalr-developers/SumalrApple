import Common
import RealmSwift
import SwiftUI
import WebKit

@main struct SumalrApp: App {
    @State var showWebPreview = false
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.showWebPreview, $showWebPreview)
        }
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
    @Environment(\.showWebPreview) var showWebPreview
    @Environment(\.realm) var realm

    @State var errorHandler = ErrorHandler()
    @State var rlamusClient: RlamusClient? = RlamusClient(endpoint: URL(string: "https://rlamus.tail8a9e0.ts.net")!)
    @State var webPreviewPage = WebPage()

    var body: some View {
        TabView {
            Tab("Library", systemImage: "books.vertical") {
                NavigationStack {
                    LibraryPage()
                        .navigationTitle("Sumalr")
                }
            }

            Tab("Account", systemImage: "person.circle") {
            }
        }
        .environment(\.errorHandler, errorHandler)
        .environment(\.rlamusClient, $rlamusClient)
        .alert(error: $errorHandler.current) {
            Button(role: .cancel) {
                errorHandler.current = nil
            }
        }
        .sheet(isPresented: showWebPreview) {
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
            }
        }
    }
}

#Preview {
    ContentView()
}
