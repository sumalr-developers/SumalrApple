import Foundation
import SwiftUI

struct MarkdownText: View {
    let markdown: String

    init(_ markdown: String) {
        self.markdown = markdown
    }

    var body: some View {
        if let md = try? AttributedString(markdown: normalizedMarkdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(md)
        } else {
            Text(markdown)
        }
    }

    var normalizedMarkdown: String {
        markdown.replacingOccurrences(of: "\n\n", with: "\n")
    }
}
