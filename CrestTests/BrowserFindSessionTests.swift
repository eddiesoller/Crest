import XCTest

@testable import Crest

@MainActor
final class BrowserFindSessionTests: XCTestCase {
    /// The page answers with its selection a moment after find opens. By then
    /// the person may already be typing, and what they typed must win.
    func testSelectionStartsOpeningFindUnlessThePersonTypedFirst() {
        let session = BrowserFindSession()
        let executor = RecordingFindExecutor()
        var answer: (@MainActor (String?) -> Void)?

        session.present(hasLoadedPage: true, seedingFrom: { answer = $0 }, using: executor)
        answer?("Crest")
        XCTAssertEqual(session.query, "Crest")
        XCTAssertEqual(executor.queries.last, "Crest")

        session.dismiss(using: executor)
        session.present(hasLoadedPage: true, seedingFrom: { answer = $0 }, using: executor)
        session.find("typed", using: executor)
        let searchedBeforeAnswer = executor.queries.count
        answer?("Crest")
        XCTAssertEqual(session.query, "typed")
        XCTAssertEqual(executor.queries.count, searchedBeforeAnswer, "A late selection must not search.")
    }
}

/// Records every query the session asks the page to find.
@MainActor
private final class RecordingFindExecutor: BrowserFindExecuting {
    private(set) var queries: [String] = []

    func performFind(
        _ query: String,
        configuration: BrowserFindConfiguration,
        completion: @escaping @MainActor (BrowserFindResult) -> Void
    ) {
        queries.append(query)
        completion(BrowserFindResult(matchFound: !query.isEmpty))
    }
}
