import XCTest

final class InputControllerBehaviorTests: XCTestCase {
    func testEmptyCandidatesCommitMappedFallbackWhenPossible() {
        var behavior = makeBehavior(dictionaryText: "привет 10")
        behavior.startComposition(rawInput: "qqq", refresh: false)

        XCTAssertEqual(behavior.commitSelectedText(), "ййй")
        XCTAssertFalse(behavior.hasComposition)
    }

    func testEmptyCandidatesCommitRawFallbackWhenInputCannotMap() {
        var behavior = makeBehavior(dictionaryText: "привет 10")
        behavior.startComposition(rawInput: "abc1", refresh: false)

        XCTAssertEqual(behavior.commitSelectedText(), "abc1")
        XCTAssertFalse(behavior.hasComposition)
    }

    func testNumberSelectionCommitsCandidateFromCurrentPage() {
        var behavior = makeBehavior(dictionaryText: """
        как 100
        когда 90
        кто 80
        клавиатура 70
        код 60
        кот 50
        комната 40
        карта 30
        кино 20
        """)
        behavior.startComposition(rawInput: "r")

        XCTAssertEqual(behavior.selectCandidate(localIndex: 1), "когда")
        XCTAssertFalse(behavior.hasComposition)
    }

    func testPageNavigationMovesHighlightToPageStart() {
        var behavior = makeBehavior(dictionaryText: """
        как 100
        когда 90
        кто 80
        клавиатура 70
        код 60
        кот 50
        комната 40
        карта 30
        кино 20
        километр 10
        """)
        behavior.startComposition(rawInput: "r")

        XCTAssertEqual(behavior.pageLabelText, "1/2")
        XCTAssertEqual(behavior.localHighlightedCandidateIndex, 0)

        behavior.movePage(by: 1)

        XCTAssertEqual(behavior.pageLabelText, "2/2")
        XCTAssertEqual(behavior.highlightedCandidateIndex, 8)
        XCTAssertEqual(behavior.localHighlightedCandidateIndex, 0)
        XCTAssertEqual(behavior.visibleCandidates.map(\.text), ["кино", "километр"])

        behavior.movePage(by: -1)

        XCTAssertEqual(behavior.pageLabelText, "1/2")
        XCTAssertEqual(behavior.highlightedCandidateIndex, 0)
    }

    func testShiftHoldEnablesTemporaryEnglishWithoutTogglingAfterKeyEvent() {
        var preferences = InputPreferences.default
        preferences.enableTemporaryEnglishMode = true
        var behavior = makeBehavior(preferences: preferences)

        XCTAssertTrue(behavior.handleFlagsChanged(keyCode: 56, flags: [.shift]))
        XCTAssertEqual(behavior.effectiveInputMode, .english)

        behavior.noteKeyEventDuringShift()
        XCTAssertTrue(behavior.handleFlagsChanged(keyCode: 56, flags: []))

        XCTAssertEqual(behavior.inputMode, .russian)
        XCTAssertEqual(behavior.effectiveInputMode, .russian)
    }

    func testSingleShiftClickTogglesEnglishMode() {
        var preferences = InputPreferences.default
        preferences.enableTemporaryEnglishMode = true
        var behavior = makeBehavior(preferences: preferences)

        XCTAssertTrue(behavior.handleFlagsChanged(keyCode: 56, flags: [.shift]))
        XCTAssertEqual(behavior.effectiveInputMode, .english)
        XCTAssertTrue(behavior.handleFlagsChanged(keyCode: 56, flags: []))

        XCTAssertEqual(behavior.inputMode, .english)
        XCTAssertEqual(behavior.effectiveInputMode, .english)
    }

    func testCapsLockPassthroughCommitsCompositionThenLetsKeyPassThrough() {
        var preferences = InputPreferences.default
        preferences.capsLockBehavior = .passthrough
        var behavior = makeBehavior(dictionaryText: "привет 10", preferences: preferences)
        behavior.startComposition(rawInput: "ghb")

        XCTAssertEqual(behavior.handleCharacter("a", flags: [.capsLock]), .commitAndPassThrough("привет"))
        XCTAssertFalse(behavior.hasComposition)
    }

    func testCapsLockToggleEnglishCommitsCompositionAndSwitchesMode() {
        var preferences = InputPreferences.default
        preferences.capsLockBehavior = .toggleEnglish
        var behavior = makeBehavior(dictionaryText: "привет 10", preferences: preferences)
        behavior.startComposition(rawInput: "ghb")

        XCTAssertEqual(behavior.handleCharacter("a", flags: [.capsLock]), .commitAndPassThrough("привет"))
        XCTAssertEqual(behavior.inputMode, .english)
        XCTAssertFalse(behavior.hasComposition)
    }

    func testCapsLockUppercaseRussianAppendsUppercaseMappedText() {
        var preferences = InputPreferences.default
        preferences.capsLockBehavior = .uppercaseRussian
        var behavior = makeBehavior(dictionaryText: "ПРИВЕТ 10", preferences: preferences)

        XCTAssertEqual(behavior.handleCharacter("q", flags: [.capsLock]), .handled)

        XCTAssertEqual(behavior.rawInput, "Q")
        XCTAssertEqual(behavior.commitSelectedText(), "Й")
    }

    func testPreferenceChangesRefreshCompositionCandidates() {
        var preferences = InputPreferences.default
        preferences.enableCustomDictionary = true
        preferences.customDictionaryText = "привет 10"
        var behavior = makeBehavior(dictionaryText: "приказ 50", preferences: preferences)
        behavior.startComposition(rawInput: "ghb")

        XCTAssertEqual(behavior.currentCandidates.first?.text, "приказ")

        preferences.customDictionaryText = "пример 500"
        behavior.updatePreferences(preferences)

        XCTAssertEqual(behavior.rawInput, "ghb")
        XCTAssertEqual(behavior.currentCandidates.first?.text, "пример")
    }

    private func makeBehavior(
        dictionaryText: String = "привет 10",
        preferences: InputPreferences = .default
    ) -> InputControllerBehavior {
        let engine = InputEngine(
            dictionaryText: dictionaryText,
            preferences: preferences,
            userLexicon: TestLearningStore()
        )
        return InputControllerBehavior(engine: engine, preferences: preferences)
    }
}
