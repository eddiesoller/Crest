import WebKit
import XCTest

@testable import Crest

@MainActor
final class BrowserFindSelectionTests: XCTestCase {
    func testFindStartsFromSelectedTextButNeverFromAPasswordField() async throws {
        let web = try await fixture()

        try await select("text", in: web)
        let fromText = await read(from: web)
        try await select("plain", in: web)
        let fromPage = await read(from: web)
        try await select("password", in: web)
        let fromPassword = await read(from: web)
        try await select("masked", in: web)
        let fromMasked = await read(from: web)
        try await select("masked-editable", in: web)
        let fromMaskedEditable = await read(from: web)
        try await select("partly-masked", in: web)
        let fromPartlyMasked = await read(from: web)

        XCTAssertEqual(fromText, "visible secret")
        XCTAssertEqual(fromPage, "Code visible ok")
        XCTAssertNil(fromPassword, "A password field's selection must never become the find query.")
        XCTAssertNil(fromMasked, "A text field masked like a password must never become the find query.")
        XCTAssertNil(fromMaskedEditable, "Editable text masked like a password must never become the find query.")
        XCTAssertNil(fromPartlyMasked, "A selection that takes in masked text must never become the find query.")
    }

    func testFindStartsFromAWordInsideALongParagraph() async throws {
        let web = try await fixture()
        _ = try await web.evaluateJavaScript(
            """
            {
              const text = document.getElementById('long').firstChild;
              const start = text.data.indexOf('needle');
              const range = document.createRange();
              range.setStart(text, start);
              range.setEnd(text, start + 6);
              getSelection().removeAllRanges();
              getSelection().addRange(range);
            }
            """
        )

        let query = await read(from: web)

        XCTAssertEqual(query, "needle", "Only the selected text counts toward the length limit.")
    }

    /// Focuses element `id` and selects all of its text, as a person would.
    /// Selecting page text takes focus away from a field, as a drag does.
    private func select(_ id: String, in web: WKWebView) async throws {
        _ = try await web.evaluateJavaScript(
            """
            {
              const element = document.getElementById('\(id)');
              document.activeElement?.blur();
              element.focus();
              if (element.setSelectionRange) {
                element.setSelectionRange(0, element.value.length);
              } else {
                getSelection().selectAllChildren(element);
              }
            }
            """
        )
    }

    private func read(from web: WKWebView) async -> String? {
        await withCheckedContinuation { continuation in
            BrowserFindSelection(webView: web).read { continuation.resume(returning: $0) }
        }
    }

    private func fixture() async throws -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        web.loadHTMLString(
            """
            <html><body><input id="text" value="visible secret">
            <input id="password" type="password" value="visible secret">
            <input id="masked" style="-webkit-text-security: disc" value="visible secret">
            <div id="masked-editable" contenteditable style="-webkit-text-security: disc">visible secret</div>
            <p id="plain">Code <span>visible</span> ok</p>
            <p id="partly-masked">Code <span style="-webkit-text-security: disc">4821</span> ok</p>
            <p id="long"></p>
            <script>
            document.getElementById('long').textContent = 'word '.repeat(240) + 'needle ' + 'word '.repeat(240);
            </script>
            </body></html>
            """, baseURL: URL(string: "https://find.crest.test"))
        for _ in 0..<100 {
            if !web.isLoading, (try? await web.evaluateJavaScript("document.readyState")) as? String == "complete" {
                return web
            }
            try await Task.sleep(for: .milliseconds(30))
        }
        XCTFail("Find fixture did not load")
        return web
    }
}
