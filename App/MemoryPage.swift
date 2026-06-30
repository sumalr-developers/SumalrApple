import Common
import Foundation
import SwiftUI
import Textual

struct MemoryPage: View {
    @Environment(\.openURL) var openURL
    @State var summary: String = ""
    
    let item: TrackedTask?
    init(_ item: TrackedTask? = nil) {
        self.item = item
    }

    var body: some View {
        if let item {
            ScrollView(.vertical) {
                VStack {
                    StructuredText(markdown: summary)
                        .textual.textSelection(.enabled)
                    Text("Created \(Text(item.creation, style: .relative)) ago")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top)
                        .safeAreaPadding(.bottom)
                }
                .padding(.horizontal)
                .onAppear {
                    if let summary = item.value.summary {
                        self.summary = summary
                    }
                }
                .onChange(of: item.value) { oldValue, newValue in
                    if let summary = newValue.summary {
                        self.summary = summary
                    }
                }
            }
            .navigationTitle(item.title ?? String(localized: "Unnamed memory"))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Open in browswer", systemImage: "arrow.up.forward.app") {
                            openURL(item.url)
                        }
                    }
                }
        } else {
            Text("Item not found")
        }
    }
}
