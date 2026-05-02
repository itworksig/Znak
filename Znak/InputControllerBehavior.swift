import Foundation

struct InputControllerBehavior {
    static let maxCompositionLength = 20
    static let candidatePageSize = 8

    enum InputMode: Equatable {
        case russian
        case english
    }

    struct KeyFlags: OptionSet, Equatable {
        let rawValue: Int

        static let shift = KeyFlags(rawValue: 1 << 0)
        static let capsLock = KeyFlags(rawValue: 1 << 1)
        static let command = KeyFlags(rawValue: 1 << 2)
        static let control = KeyFlags(rawValue: 1 << 3)
        static let option = KeyFlags(rawValue: 1 << 4)
    }

    enum KeyResult: Equatable {
        case handled
        case passThrough
        case commitAndPassThrough(String)
    }

    private struct StandaloneShiftState {
        var pressedKeyCode: UInt16?
        var hadInterveningKeyEvent = false
        var hadInterveningModifier = false

        var isPending: Bool { pressedKeyCode != nil }

        mutating func begin(with keyCode: UInt16) {
            pressedKeyCode = keyCode
            hadInterveningKeyEvent = false
            hadInterveningModifier = false
        }

        mutating func noteKeyEvent() {
            guard isPending else { return }
            hadInterveningKeyEvent = true
        }

        mutating func noteOtherModifier() {
            guard isPending else { return }
            hadInterveningModifier = true
        }

        mutating func cancel() {
            pressedKeyCode = nil
            hadInterveningKeyEvent = false
            hadInterveningModifier = false
        }

        func shouldToggle(on releaseKeyCode: UInt16) -> Bool {
            pressedKeyCode == releaseKeyCode && !hadInterveningKeyEvent && !hadInterveningModifier
        }
    }

    var engine: InputEngine
    var preferences: InputPreferences
    var rawInput = ""
    var currentCandidates: [InputEngine.Candidate] = []
    var highlightedCandidateIndex = 0
    var currentPageIndex = 0
    var inputMode: InputMode = .russian
    var previousCommittedWord: String?
    var temporaryEnglishActive = false

    private var lastModifierFlags: KeyFlags = []
    private var standaloneShiftState = StandaloneShiftState()

    init(
        engine: InputEngine,
        preferences: InputPreferences = .default,
        inputMode: InputMode = .russian
    ) {
        self.engine = engine
        self.preferences = preferences.sanitized
        self.inputMode = inputMode
        self.engine.updatePreferences(self.preferences)
    }

    var hasComposition: Bool { !rawInput.isEmpty }

    var effectiveInputMode: InputMode {
        temporaryEnglishActive ? .english : inputMode
    }

    var visibleCandidates: ArraySlice<InputEngine.Candidate> {
        guard !currentCandidates.isEmpty else { return [] }
        return currentCandidates[currentPageRange]
    }

    var pageLabelText: String {
        guard pageCount > 1 else { return "" }
        return "\(currentPageIndex + 1)/\(pageCount)"
    }

    var localHighlightedCandidateIndex: Int {
        max(0, highlightedCandidateIndex - currentPageRange.lowerBound)
    }

    mutating func updatePreferences(_ newPreferences: InputPreferences) {
        preferences = newPreferences.sanitized
        engine.updatePreferences(preferences)
        guard hasComposition else { return }
        refreshCandidates()
    }

    mutating func replaceUserLexicon(_ userLexicon: any InputLearningStore) {
        engine.replaceUserLexicon(userLexicon)
        guard hasComposition else { return }
        refreshCandidates()
    }

    mutating func startComposition(rawInput: String, refresh: Bool = true) {
        self.rawInput = rawInput
        highlightedCandidateIndex = 0
        currentPageIndex = 0
        if refresh {
            refreshCandidates()
        } else {
            currentCandidates.removeAll()
        }
    }

    mutating func refreshCandidates() {
        currentCandidates = engine.candidates(
            for: rawInput,
            previousWord: previousCommittedWord,
            limit: preferences.maxCandidateCount
        )
        clampHighlightedCandidateIndex()
        syncPageToHighlightedCandidate()
    }

    mutating func handleCharacter(_ characters: String, flags: KeyFlags = []) -> KeyResult {
        standaloneShiftState.noteKeyEvent()

        if flags.contains(.capsLock) {
            switch preferences.capsLockBehavior {
            case .passthrough:
                if hasComposition {
                    return .commitAndPassThrough(commitBestText())
                }
                return .passThrough
            case .toggleEnglish:
                inputMode = .english
                if hasComposition {
                    return .commitAndPassThrough(commitBestText())
                }
                return .passThrough
            case .uppercaseRussian:
                break
            }
        }

        if flags.intersection([.command, .control, .option]).isEmpty == false {
            standaloneShiftState.cancel()
            return .passThrough
        }

        if effectiveInputMode == .english {
            if hasComposition {
                return .commitAndPassThrough(commitBestText())
            }
            return .passThrough
        }

        guard characters.count == 1,
              engine.mappedText(for: characters) != nil else {
            if hasComposition {
                return .commitAndPassThrough(commitSelectedText())
            }
            return .passThrough
        }

        if rawInput.count >= Self.maxCompositionLength {
            _ = commitSelectedText()
        }

        let appendedCharacters = flags.contains(.shift) || (flags.contains(.capsLock) && preferences.capsLockBehavior == .uppercaseRussian)
            ? characters.uppercased()
            : characters
        rawInput.append(appendedCharacters)
        refreshCandidates()
        return .handled
    }

    mutating func handleFlagsChanged(keyCode: UInt16, flags: KeyFlags) -> Bool {
        let previousFlags = lastModifierFlags
        lastModifierFlags = flags

        let shiftWasDown = previousFlags.contains(.shift)
        let shiftIsDown = flags.contains(.shift)
        let nonShiftFlags = flags.subtracting(.shift)
        let previousNonShiftFlags = previousFlags.subtracting(.shift)
        let isShiftKey = keyCode == 56 || keyCode == 60

        if standaloneShiftState.isPending,
           nonShiftFlags != previousNonShiftFlags || !nonShiftFlags.isEmpty {
            standaloneShiftState.noteOtherModifier()
        }

        if isShiftKey && !shiftWasDown && shiftIsDown {
            standaloneShiftState.begin(with: keyCode)
            if !nonShiftFlags.isEmpty {
                standaloneShiftState.noteOtherModifier()
            }
            return true
        }

        if isShiftKey && shiftWasDown && !shiftIsDown {
            let shouldToggle = standaloneShiftState.shouldToggle(on: keyCode)
            standaloneShiftState.cancel()
            if shouldToggle {
                inputMode = inputMode == .russian ? .english : .russian
            }
            return true
        }

        if !shiftIsDown {
            standaloneShiftState.cancel()
        }

        return false
    }

    mutating func noteKeyEventDuringShift() {
        standaloneShiftState.noteKeyEvent()
    }

    mutating func commitSelectedText() -> String {
        clampHighlightedCandidateIndex()
        if currentCandidates.indices.contains(highlightedCandidateIndex) {
            return commitCandidate(at: highlightedCandidateIndex)
        }
        return commit(commitFallbackText())
    }

    mutating func commitBestText() -> String {
        let text = currentCandidates.first?.text ?? commitFallbackText()
        return commit(text)
    }

    mutating func selectCandidate(localIndex: Int) -> String? {
        guard let actualIndex = candidateIndexInCurrentPage(localIndex: localIndex),
              currentCandidates.indices.contains(actualIndex) else {
            return nil
        }
        return commitCandidate(at: actualIndex)
    }

    mutating func moveSelection(by delta: Int) {
        guard !currentCandidates.isEmpty else { return }
        highlightedCandidateIndex = (highlightedCandidateIndex + delta + currentCandidates.count) % currentCandidates.count
        syncPageToHighlightedCandidate()
    }

    mutating func movePage(by delta: Int) {
        guard pageCount > 1 else { return }

        let nextPage = min(max(currentPageIndex + delta, 0), pageCount - 1)
        guard nextPage != currentPageIndex else { return }

        currentPageIndex = nextPage
        let pageRange = currentPageRange
        highlightedCandidateIndex = min(pageRange.lowerBound, currentCandidates.count - 1)
    }

    private mutating func commitCandidate(at index: Int) -> String {
        highlightedCandidateIndex = index
        let selectedText = currentCandidates[index].text
        let selectedInput = rawInput
        engine.learnSelection(selectedText, for: selectedInput, previousWord: previousCommittedWord)
        return commit(selectedText)
    }

    private mutating func commit(_ text: String) -> String {
        previousCommittedWord = normalizedCommittedWord(from: text)
        resetComposition()
        return text
    }

    private mutating func resetComposition() {
        rawInput.removeAll()
        currentCandidates.removeAll()
        highlightedCandidateIndex = 0
        currentPageIndex = 0
        temporaryEnglishActive = false
        standaloneShiftState.cancel()
    }

    private func commitFallbackText() -> String {
        engine.mappedText(for: rawInput) ?? rawInput
    }

    private var currentPageRange: Range<Int> {
        let start = min(currentPageIndex * Self.candidatePageSize, max(currentCandidates.count - 1, 0))
        let end = min(start + Self.candidatePageSize, currentCandidates.count)
        return start..<max(start, end)
    }

    private var pageCount: Int {
        guard !currentCandidates.isEmpty else { return 0 }
        return (currentCandidates.count + Self.candidatePageSize - 1) / Self.candidatePageSize
    }

    private func candidateIndexInCurrentPage(localIndex: Int) -> Int? {
        let actualIndex = currentPageRange.lowerBound + localIndex
        return currentCandidates.indices.contains(actualIndex) ? actualIndex : nil
    }

    private mutating func syncPageToHighlightedCandidate() {
        guard !currentCandidates.isEmpty else {
            currentPageIndex = 0
            return
        }
        currentPageIndex = highlightedCandidateIndex / Self.candidatePageSize
    }

    private mutating func clampHighlightedCandidateIndex() {
        if currentCandidates.isEmpty {
            highlightedCandidateIndex = 0
        } else {
            highlightedCandidateIndex = min(highlightedCandidateIndex, currentCandidates.count - 1)
        }
    }

    private func normalizedCommittedWord(from text: String) -> String? {
        let trimmed = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return trimmed.isEmpty ? nil : trimmed
    }
}
