import Foundation
import Testing
import Common

struct WebPageTitleTests {
    @Test("Get various site's title metadata", arguments: [
        ("https://example.com", "Example Domain"),
        ("https://duckduckgo.com", "DuckDuckGo - Protection. Privacy. Peace of mind."),
        ("https://http.cat", "HTTP Cats"),
        ("https://en.wikipedia.org/wiki/The_Amazing_Digital_Circus", "The Amazing Digital Circus - Wikipedia")
    ])
    func getTitles(url: String, expectedTitle: String?) async throws {
        let title = try await getWebPageTitle(url: URL(string: url)!)
        #expect(title == expectedTitle)
    }
}
