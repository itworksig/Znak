import XCTest

final class InputEnginePerformanceTests: XCTestCase {
    func testIncrementalCandidateLookupPerformance() {
        let dictionaryText = makeLargeDictionary(prefix: "привет", transliterationInput: "ghbdtn", count: 1_500)
        let preferences = performancePreferences()

        measure {
            var engine = InputEngine(
                dictionaryText: dictionaryText,
                preferences: preferences,
                userLexicon: makeLargeLearningStore(count: 800)
            )
            for input in ["g", "gh", "ghb", "ghbd", "ghbdt", "ghbdtn"] {
                XCTAssertLessThanOrEqual(engine.candidates(for: input, previousWord: "добрый", limit: 24).count, 24)
            }
        }
    }

    func testFuzzyPoolPerformanceWithLargeDictionary() {
        let dictionaryText = makeLargeDictionary(prefix: "привет", transliterationInput: "ghbdtn", count: 2_000)
        let preferences = performancePreferences()

        measure {
            var engine = InputEngine(
                dictionaryText: dictionaryText,
                preferences: preferences,
                userLexicon: TestLearningStore()
            )
            let candidates = engine.candidates(for: "prkv", previousWord: nil, limit: 24)
            XCTAssertLessThanOrEqual(candidates.count, 24)
        }
    }

    func testPhraseLookupPerformanceDoesNotDominateCommonInput() {
        let phraseCandidates = (0..<1_000).map { index in
            InputEngine.PhraseCandidate(
                anchor: index.isMultiple(of: 2) ? "добрый" : nil,
                text: "привет тест \(index)",
                frequency: 1_000 - index,
                normalizedText: "привет тест \(index)",
                transliteration: InputEngine.transliterationKey(for: "привет тест \(index)")
            )
        }
        let learningStore = TestLearningStore(phraseCandidates: phraseCandidates)

        measure {
            var engine = InputEngine(
                dictionaryText: "привет 100\nприказ 90\nпример 80",
                preferences: performancePreferences(),
                userLexicon: learningStore
            )
            let candidates = engine.candidates(for: "ghb", previousWord: "добрый", limit: 24)
            XCTAssertEqual(candidates.first?.text, "привет")
            XCTAssertLessThanOrEqual(candidates.count, 24)
        }
    }

    private func performancePreferences() -> InputPreferences {
        var preferences = InputPreferences.default
        preferences.enableLatinPrediction = true
        preferences.enableAutoCorrection = true
        preferences.enablePrediction = true
        preferences.maxCandidateCount = 24
        return preferences
    }

    private func makeLargeDictionary(prefix: String, transliterationInput: String, count: Int) -> String {
        var rows = ["\(prefix) 5000"]
        rows.reserveCapacity(count + 1)
        for index in 0..<count {
            let suffix = String(index, radix: 36)
            rows.append("\(prefix)\(suffix) \(count - index)")
        }
        rows.append("проект 400")
        rows.append("пример 350")
        rows.append("приказ 300")
        rows.append("проверка 250")
        rows.append("правка 200")
        rows.append("\(transliterationInput) 1")
        return rows.joined(separator: "\n")
    }

    private func makeLargeLearningStore(count: Int) -> TestLearningStore {
        var bonuses: [String: Int] = ["привет": 1_000]
        for index in 0..<count {
            bonuses["привет\(String(index, radix: 36))"] = count - index
        }
        return TestLearningStore(frequencyBonuses: bonuses)
    }
}
