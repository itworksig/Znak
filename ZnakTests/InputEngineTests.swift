import XCTest

final class InputEngineTests: XCTestCase {
    private var engine = InputEngine(preferences: .default, userLexicon: TestLearningStore())

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
        var engine = makeEngine(preferences: latinPredictionPreferences)
        let candidates = engine.candidates(for: "priv").map(\.text)

        XCTAssertEqual(candidates.first, "привет")
        XCTAssertTrue(candidates.contains("привет"))
    }

    func testCandidatesAllowSingleTypoFuzzyMatch() {
        var engine = makeEngine(preferences: latinPredictionPreferences)
        let candidates = engine.candidates(for: "prkv").map(\.text)

        XCTAssertTrue(candidates.contains("привет"))
    }

    func testPreviewTextUsesBestCandidate() {
        var engine = makeEngine(preferences: latinPredictionPreferences)
        XCTAssertEqual(engine.previewText(for: "priv"), "привет")
    }

    func testCandidatesFallbackToMappedPrefixWhenNoWordMatches() {
        XCTAssertEqual(engine.candidates(for: "qqq").map(\.text), ["ййй"])
    }

    func testDictionaryTextControlsCandidateOrder() {
        var engine = makeEngine(dictionaryText: """
        # comment
        привет 10
        приказ 30
        пример 20
        """)

        XCTAssertEqual(engine.candidates(for: "ghb").map(\.text), ["приказ", "пример", "привет"])
    }

    func testDictionaryTextAllowsWordsWithoutFrequency() {
        var engine = makeEngine(dictionaryText: "привет")

        XCTAssertEqual(engine.candidates(for: "ghb").map(\.text), ["привет"])
    }

    func testCandidatesLimitToRequestedCount() {
        var engine = makeEngine(dictionaryText: """
        когда 50
        кто 40
        клавиатура 30
        код 20
        комната 10
        """)

        XCTAssertEqual(engine.candidates(for: "r", limit: 3).count, 3)
    }

    func testMappedFallbackOnlyAppearsWhenNoDictionaryMatches() {
        var engine = makeEngine(dictionaryText: """
        как 100
        когда 90
        кто 80
        """)

        XCTAssertFalse(engine.candidates(for: "r").map(\.text).contains("к"))
    }

    func testContextBonusReordersWithinDictionaryLayer() {
        let learningStore = TestLearningStore(
            frequencyBonuses: [
                "пример": 1000
            ]
        )
        var engine = InputEngine(
            dictionaryText: """
            приказ 300
            пример 10
            привет 20
            """,
            preferences: .default,
            userLexicon: learningStore
        )

        XCTAssertEqual(engine.candidates(for: "ghb").map(\.text), ["пример", "приказ", "привет"])
    }

    func testPhraseLayerDoesNotOutrankDictionaryLayer() {
        let learningStore = TestLearningStore(
            phraseCandidates: [
                InputEngine.PhraseCandidate(
                    anchor: nil,
                    text: "при очень",
                    frequency: 99_999,
                    normalizedText: "при очень",
                    transliteration: InputEngine.transliterationKey(for: "при очень")
                )
            ]
        )
        var engine = InputEngine(
            dictionaryText: "привет 10",
            preferences: .default,
            userLexicon: learningStore
        )

        XCTAssertEqual(engine.candidates(for: "ghb").map(\.text), ["привет", "при очень"])
    }

    func testFuzzyLayerComesAfterPhraseLayer() {
        let learningStore = TestLearningStore(
            phraseCandidates: [
                InputEngine.PhraseCandidate(
                    anchor: nil,
                    text: "пркв тест",
                    frequency: 1,
                    normalizedText: "пркв тест",
                    transliteration: InputEngine.transliterationKey(for: "пркв тест")
                )
            ]
        )
        var engine = InputEngine(
            dictionaryText: "привет 10",
            preferences: latinPredictionPreferences,
            userLexicon: learningStore
        )

        XCTAssertEqual(engine.candidates(for: "prkv").map(\.text), ["пркв тест", "привет"])
    }

    func testUserLexiconMigratesVersionedDataWithMissingNewFields() throws {
        let directory = try makeTemporaryDirectory()
        let url = directory.appendingPathComponent("user_dictionary.json")
        let legacyJSON = """
        {
          "version": 1,
          "wordScores": {
            "привет": 24
          },
          "inputWordScores": {
            "ghbdtn": {
              "привет": 36
            }
          }
        }
        """
        try legacyJSON.data(using: .utf8)?.write(to: url, options: .atomic)

        let store = UserLexiconStore(storageDirectory: directory)

        XCTAssertTrue(store.learnedWords.contains("привет"))
        XCTAssertGreaterThan(store.frequencyBonus(for: "привет", input: "ghbdtn", previousWord: nil), 0)
    }

    func testUserLexiconMigratesLegacyWordScoreDictionary() throws {
        let directory = try makeTemporaryDirectory()
        let url = directory.appendingPathComponent("user_dictionary.json")
        let legacyJSON = """
        {
          "спасибо": 48
        }
        """
        try legacyJSON.data(using: .utf8)?.write(to: url, options: .atomic)

        let store = UserLexiconStore(storageDirectory: directory)

        XCTAssertTrue(store.learnedWords.contains("спасибо"))
        XCTAssertGreaterThan(store.maxFrequencyBonus(for: "спасибо"), 0)
    }

    func testUserLexiconDoesNotLearnPhrasesPunctuationOrAbnormalInput() throws {
        let directory = try makeTemporaryDirectory()
        var store = UserLexiconStore(storageDirectory: directory)

        store.recordSelection("привет мир", input: "ghbdtn", previousWord: nil)
        store.recordSelection("привет!", input: "ghbdtn", previousWord: nil)
        store.recordSelection("привет", input: "ghbdtn1", previousWord: nil)
        store.recordSelection("спасибо", input: "spa sibo", previousWord: nil)
        store.recordSelection("пока", input: "gjrf", previousWord: nil)

        XCTAssertFalse(store.learnedWords.contains("привет мир"))
        XCTAssertFalse(store.learnedWords.contains("привет!"))
        XCTAssertFalse(store.learnedWords.contains("привет"))
        XCTAssertFalse(store.learnedWords.contains("спасибо"))
        XCTAssertTrue(store.learnedWords.contains("пока"))
    }

    private var latinPredictionPreferences: InputPreferences {
        var preferences = InputPreferences.default
        preferences.enableLatinPrediction = true
        return preferences
    }

    private func makeEngine(preferences: InputPreferences = .default) -> InputEngine {
        InputEngine(preferences: preferences, userLexicon: TestLearningStore())
    }

    private func makeEngine(dictionaryText: String, preferences: InputPreferences = .default) -> InputEngine {
        InputEngine(dictionaryText: dictionaryText, preferences: preferences, userLexicon: TestLearningStore())
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZnakTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}

struct TestLearningStore: InputLearningStore {
    var frequencyBonuses: [String: Int] = [:]
    var phraseCandidates: [InputEngine.PhraseCandidate] = []

    var learnedWords: [String] { [] }

    func maxFrequencyBonus(for word: String) -> Int { 0 }

    func frequencyBonus(for word: String, input: String, previousWord: String?) -> Int {
        frequencyBonuses[word.lowercased()] ?? 0
    }

    func learnedPhraseCandidates(after previousWord: String?) -> [InputEngine.PhraseCandidate] {
        phraseCandidates
    }

    mutating func recordSelection(_ word: String, input: String, previousWord: String?) {}
}
