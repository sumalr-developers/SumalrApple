import Foundation
import WebKit

@MainActor
public func getWebPageTitle(url: URL, session: URLSession = .shared) async throws -> String? {
    let webview = WKWebView()
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .nonPersistent()
    let cbID = "com.zhufucdev.getWebPageTitle"
    let store = WKContentRuleListStore.default()!
    if let rule = try? await store.contentRuleList(forIdentifier: cbID) {
        config.userContentController.add(rule)
    } else {
        let rulesURL = Bundle(for: NavigationDeleage.self).url(forResource: "AllowHtmlOnlyRules", withExtension: "json")!
        let jsonContent = try! Data(contentsOf: rulesURL)
        let rule = try await store.compileContentRuleList(forIdentifier: cbID, encodedContentRuleList: String(data: jsonContent, encoding: .utf8))!
        config.userContentController.add(rule)
    }
    let delegate = NavigationDeleage()
    webview.navigationDelegate = delegate
    return await withCheckedContinuation { continuation in
        delegate.onFinish = {
            continuation.resume(returning: webview.title?.isEmpty == false ? webview.title : nil)
        }
        webview.load(url)
    }
}

fileprivate class NavigationDeleage: NSObject, WKNavigationDelegate {
    var onFinish: () -> Void = {}

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onFinish()
    }
}

fileprivate class TitleParser: NSObject, XMLParserDelegate {
    var title: String?
    private var hierarchy: [String] = []

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if hierarchy == ["html", "head", "title"] {
            title = string
            parser.abortParsing()
        } else if hierarchy == ["html", "body"] {
            parser.abortParsing()
        }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        hierarchy.append(elementName)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        while hierarchy.last != elementName {
            _ = hierarchy.popLast()
        }
        _ = hierarchy.popLast()
    }
}
