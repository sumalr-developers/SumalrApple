import Common
import SwiftUI

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
