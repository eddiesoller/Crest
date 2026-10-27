import WebKit

extension BrowserFindSelection {
    static let webKitWorld = WKContentWorld.world(name: "Crest.FindSelection")

    /// Sent at once: WebKit clears the selection when the find bar takes focus.
    init(webView: WKWebView) {
        self.init { [weak webView] source, answer in
            guard let webView else {
                answer(nil)
                return
            }
            webView.callAsyncJavaScript(source, arguments: [:], in: nil, in: Self.webKitWorld) { result in
                answer(try? result.get())
            }
        }
    }
}
