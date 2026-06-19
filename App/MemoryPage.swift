import Common
import Foundation
import SwiftUI
import Textual

struct MemoryPage: View {
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
            .navigationBarTitleDisplayMode(.inline)
        } else {
            Text("Item not found")
        }
    }
}
