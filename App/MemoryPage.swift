import Common
import Foundation
import SwiftUI
import Textual

struct MemoryPage: View {
    @Environment(\.openURL) var openURL
    
    let item: MemoryItem?
    init(_ item: MemoryItem? = nil) {
        self.item = item
    }

    var body: some View {
        if let item {
            ScrollView(.vertical) {
                VStack {
                    if let summary = item.summary {
                        StructuredText(markdown: summary)
                            .textual.textSelection(.enabled)
                    }
                    Text("Created \(Text(item.creation, style: .relative)) ago")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top)
                        .safeAreaPadding(.bottom)
                }
                .padding(.horizontal)
            }
            .navigationTitle(item.title ?? String(localized: "Unnamed memory"))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Open in browswer", systemImage: "arrow.up.forward.app") {
                            openURL(URL(string: item.url)!)
                        }
                    }
                }
        } else {
            Text("Item not found")
        }
    }
}
