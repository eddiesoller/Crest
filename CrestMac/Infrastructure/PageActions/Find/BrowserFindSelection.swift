import Foundation

/// The text a person selected in a page, read by a script in an isolated
/// world for find to start from.
@MainActor
struct BrowserFindSelection {
    // MARK: - Static Variables

    /// Answers the trimmed selection, or "" for nothing selected, over 250
    /// characters, a non-text or masked field, masked text, or a focused
    /// cross-origin frame, whose selection it cannot see and must not mistake
    /// for the document's older one.
    private static let source = #"""
        const limit = 250;
        const textInputTypes = ["text", "search", "url", "tel"];
        const focused = root => {
          let element = root.activeElement;
          while (element?.shadowRoot?.activeElement) element = element.shadowRoot.activeElement;
          return element;
        };
        const masked = node => {
          const element = node?.nodeType === Node.ELEMENT_NODE ? node : node?.parentElement;
          const style = element?.ownerDocument.defaultView?.getComputedStyle(element);
          const masking = style?.webkitTextSecurity;
          return !!masking && masking !== "none";
        };
        const bounded = text => {
          const trimmed = text.trim();
          return trimmed.length > limit ? "" : trimmed;
        };
        let owner = document;
        let element = focused(owner);
        while (element?.localName === "iframe" || element?.localName === "frame") {
          let inner = null;
          try { inner = element.contentDocument; } catch {}
          if (!inner) return "";
          owner = inner;
          element = focused(owner);
        }
        if (element?.localName === "textarea" || element?.localName === "input") {
          if (element.localName === "input" && !textInputTypes.includes(element.type)) return "";
          if (masked(element)) return "";
          try {
            const start = element.selectionStart, end = element.selectionEnd;
            if (start === null || end === null || end - start > limit * 4) return "";
            return bounded(element.value.slice(start, end));
          } catch { return ""; }
        }
        const selection = owner.getSelection();
        if (!selection || selection.rangeCount === 0 || selection.isCollapsed) return "";
        // Reject masked text, and stop early on a large selection, before serializing.
        const range = selection.getRangeAt(0);
        const start = range.startContainer;
        const walker = owner.createTreeWalker(range.commonAncestorContainer, NodeFilter.SHOW_TEXT);
        walker.currentNode = start.nodeType === Node.TEXT_NODE ? start : start.childNodes[range.startOffset] ?? start;
        let length = 0;
        for (let node = walker.currentNode; node; node = walker.nextNode()) {
          if (range.comparePoint(node, 0) > 0) break;
          if (node.nodeType !== Node.TEXT_NODE || !range.intersectsNode(node)) continue;
          if (node.parentElement?.closest("script, style, noscript, template")) continue;
          if (masked(node)) return "";
          const end = node === range.endContainer ? range.endOffset : node.data.length;
          length += end - (node === range.startContainer ? range.startOffset : 0);
          if (length > limit * 4) return "";
        }
        return bounded(selection.toString());
        """#

    // MARK: - Types

    /// Runs `source` as the body of an async function in the main document's
    /// find world and answers its result, or nil when the document is gone or
    /// the script failed.
    typealias Evaluate = @MainActor (_ source: String, _ answer: @escaping @MainActor (Any?) -> Void) -> Void

    // MARK: - Variables

    private let evaluate: Evaluate

    // MARK: - Initializers

    init(evaluate: @escaping Evaluate) {
        self.evaluate = evaluate
    }

    /// Chromium keeps a page's selection when its view loses focus, so the
    /// script may reach it a moment later.
    init(mainFrameOf scripting: any BrowserPageContentScripting) {
        evaluate = { [weak scripting] source, answer in
            Task { @MainActor in
                answer(try? await scripting?.callAsyncJavaScriptInMainFrame(source, arguments: [:]))
            }
        }
    }

    // MARK: - Actions - Selection

    /// Answers the selection's first line with text in it, since a search
    /// matches within a line, or nil when there is none.
    func read(_ answer: @escaping @MainActor (String?) -> Void) {
        evaluate(Self.source) { value in
            answer(Self.query(from: value as? String))
        }
    }

    private static func query(from text: String?) -> String? {
        text?.split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
    }
}
