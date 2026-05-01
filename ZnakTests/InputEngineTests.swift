import XCTest

final class InputEngineTests: XCTestCase {
    private let engine = InputEngine()

    func testQwertyMapsToLowercaseRussianKeyboardLayout() {
        XCTAssertEqual(engine.mappedText(for: "qwerty"), "йцукен")
    }

    func testShiftedQwertyMapsToUppercaseRussianKeyboardLayout() {
        XCTAssertEqual(engine.mappedText(for: "QWERTY"), "ЙЦУКЕН")
    }

    func testUppercaseSingleCharacterMapsToUppercaseRussianKeyboardLayout() {
        XCTAssertEqual(engine.mappedText(for: "K"), "Л")
    }

    func testUnmappedCharacterReturnsNil() {
        XCTAssertNil(engine.mappedCharacter(for: "1"))
    }

    func testCandidatesIncludeMappedPrefixFirst() {
        let candidates = engine.candidates(for: "ghbdtn").map(\.text)

        XCTAssertEqual(candidates.first, "привет")
        XCTAssertTrue(candidates.contains("привет"))
    }

    func testCandidatesAutocompleteRussianWords() {
        let candidates = engine.candidates(for: "ghb").map(\.text)

        XCTAssertEqual(candidates.first, "привет")
        XCTAssertTrue(candidates.contains("привет"))
    }

    func testCandidatesAutocompleteRussianKeyboardLayoutWords() {
        let candidates = engine.candidates(for: "ghb").map(\.text)

        XCTAssertEqual(candidates.first, "привет")
        XCTAssertTrue(candidates.contains("привет"))
    }

    func testCandidatesAutocompleteTransliteratedWords() {
        let candidates = engine.candidates(for: "priv").map(\.text)

        XCTAssertEqual(candidates.first, "привет")
        XCTAssertTrue(candidates.contains("привет"))
    }

    func testCandidatesAllowSingleTypoFuzzyMatch() {
        let candidates = engine.candidates(for: "prkv").map(\.text)

        XCTAssertTrue(candidates.contains("привет"))
    }

    func testPreviewTextUsesBestCandidate() {
        XCTAssertEqual(engine.previewText(for: "priv"), "привет")
    }

    func testCandidatesFallbackToMappedPrefixWhenNoWordMatches() {
        XCTAssertEqual(engine.candidates(for: "qqq").map(\.text), ["ййй"])
    }

    func testDictionaryTextControlsCandidateOrder() {
        let engine = InputEngine(dictionaryText: """
        # comment
        привет 10
        приказ 30
        пример 20
        """)

        XCTAssertEqual(engine.candidates(for: "ghb").map(\.text), ["приказ", "пример", "привет"])
    }

    func testDictionaryTextAllowsWordsWithoutFrequency() {
        let engine = InputEngine(dictionaryText: "привет")

        XCTAssertEqual(engine.candidates(for: "ghb").map(\.text), ["привет"])
    }

    func testCandidatesLimitToRequestedCount() {
        let engine = InputEngine(dictionaryText: """
        когда 50
        кто 40
        клавиатура 30
        код 20
        комната 10
        """)

        XCTAssertEqual(engine.candidates(for: "r", limit: 3).count, 3)
    }

    func testMappedFallbackOnlyAppearsWhenNoDictionaryMatches() {
        let engine = InputEngine(dictionaryText: """
        как 100
        когда 90
        кто 80
        """)

        XCTAssertFalse(engine.candidates(for: "r").map(\.text).contains("к"))
    }
}
