@preconcurrency import AppKit
@preconcurrency import InputMethodKit

final class InputController: IMKInputController {
    private static let maxCompositionLength = 20
    private static let candidatePageSize = 8
    nonisolated(unsafe) private static weak var activeController: InputController?

    private enum InputMode {
        case russian
        case english
    }

    private struct AppContext {
        let bundleIdentifier: String?
    }

    private var engine = InputEngine(
        preferences: PreferencesStore.shared.preferences.sanitized,
        userLexicon: UserLexiconStore()
    )
    private let candidateWindow: CandidateWindowController
    private var rawInput = ""
    private var currentCandidates: [InputEngine.Candidate] = []
    private var highlightedCandidateIndex = 0
    private var currentPageIndex = 0
    private var inputMode: InputMode = .russian
    private var previousCommittedWord: String?
    private var lastModifierFlags: NSEvent.ModifierFlags = []
    private var standaloneShiftState = StandaloneShiftState()
    private var preferencesObserver: NSObjectProtocol?
    private var learningResetObserver: NSObjectProtocol?
    private var appActivationObserver: NSObjectProtocol?
    private var temporaryEnglishActive = false
    private var modeToastTask: DispatchWorkItem?
    private var activeClientBundleIdentifier: String?

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

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        candidateWindow = CandidateWindowController()
        super.init(server: server, delegate: delegate, client: inputClient)
        restoreInputMode(for: inputClient)
        candidateWindow.onCandidateSelected = { [weak self] index in
            self?.selectCandidate(at: index)
        }
        candidateWindow.setInputModeLabel(inputMode == .english ? "EN" : "RU")
        preferencesObserver = NotificationCenter.default.addObserver(
            forName: .znakPreferencesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handlePreferencesDidChange()
        }
        learningResetObserver = NotificationCenter.default.addObserver(
            forName: .znakLearningDataDidReset,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleLearningDataDidReset()
        }
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleWorkspaceDidActivateApplication(notification)
        }
    }

    deinit {
        if let preferencesObserver {
            NotificationCenter.default.removeObserver(preferencesObserver)
        }
        if let learningResetObserver {
            NotificationCenter.default.removeObserver(learningResetObserver)
        }
        if let appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appActivationObserver)
        }
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        assertMainThread()
        guard let event else { return false }
        markActive(for: sender)

        if event.type == .flagsChanged {
            return handleFlagsChanged(event, sender: sender)
        }

        guard event.type == .keyDown else { return false }
        standaloneShiftState.noteKeyEvent()

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let preferences = PreferencesStore.shared.preferences.sanitized
        if flags.contains(.capsLock) {
            switch preferences.capsLockBehavior {
            case .passthrough:
                if let client = sender as? IMKTextInput, hasComposition {
                    commitBestCandidate(client: client)
                }
                return false
            case .toggleEnglish:
                setInputMode(.english, sender: sender)
                if hasComposition, let client = sender as? IMKTextInput {
                    commitBestCandidate(client: client)
                }
                return false
            case .uppercaseRussian:
                break
            }
        }

        if flags.contains(.command) || flags.contains(.control) || flags.contains(.option) {
            standaloneShiftState.cancel()
            return false
        }

        guard let client = sender as? IMKTextInput else { return false }

        if effectiveInputMode == .english {
            if hasComposition {
                commitBestCandidate(client: client)
            }
            return false
        }

        switch event.keyCode {
        // 数字键 1–8 选候选词
        case 18...29:
            guard hasComposition,
                  let localIndex = candidateIndex(for: event),
                  let index = candidateIndexInCurrentPage(localIndex: localIndex),
                  currentCandidates.indices.contains(index)
            else { break }
            commitCandidate(at: index, client: client)
            return true

        // Space / Enter → 提交当前高亮候选
        case 36, 49:
            guard hasComposition else { return false }
            commitSelectedCandidate(client: client)
            return true

        // Backspace
        case 51:
            guard hasComposition else { return false }
            rawInput.removeLast()
            updateComposition(client: client)
            return true

        // Left / Right / Up / Down / Tab
        case 123:
            guard hasComposition else { return false }
            moveSelection(by: -1)
            return true
        case 124:
            guard hasComposition else { return false }
            moveSelection(by: 1)
            return true
        case 125:
            guard hasComposition else { return false }
            movePage(by: 1)
            return true
        case 126:
            guard hasComposition else { return false }
            movePage(by: -1)
            return true
        case 48:
            guard hasComposition else { return false }
            moveSelection(by: flags.contains(.shift) ? -1 : 1)
            return true

        // Escape → 取消
        case 53:
            guard hasComposition else { return false }
            cancelComposition(client: client)
            return true

        default:
            break
        }

        guard let characters = event.characters,
              characters.count == 1,
              engine.mappedText(for: characters) != nil
        else {
            if hasComposition { commitSelectedCandidate(client: client) }
            return false
        }

        if rawInput.count >= Self.maxCompositionLength {
            commitSelectedCandidate(client: client)
        }

        let appendedCharacters: String
        if flags.contains(.shift) || (flags.contains(.capsLock) && preferences.capsLockBehavior == .uppercaseRussian) {
            appendedCharacters = characters.uppercased()
        } else {
            appendedCharacters = characters
        }

        rawInput.append(appendedCharacters)
        updateComposition(client: client)
        return true
    }

    override func candidates(_ sender: Any!) -> [Any]! {
        assertMainThread()
        markActive(for: sender)
        return currentCandidates.map(\.text)
    }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        assertMainThread()
        guard let candidateString,
              hasComposition,
              let index = currentCandidates.firstIndex(where: { $0.text == candidateString.string }),
              let client = client() else {
            return
        }
        commitCandidate(at: index, client: client)
    }

    override func commitComposition(_ sender: Any!) {
        assertMainThread()
        markActive(for: sender)
        guard let client = sender as? IMKTextInput, hasComposition else { return }
        commitSelectedCandidate(client: client)
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue | NSEvent.EventTypeMask.flagsChanged.rawValue)
    }

    // MARK: - Private

    private var hasComposition: Bool { !rawInput.isEmpty }

    private func markActive(for sender: Any!) {
        if let activeController = Self.activeController, activeController !== self {
            activeController.abandonComposition()
        }
        Self.activeController = self
        activeClientBundleIdentifier = appContext(for: sender).bundleIdentifier
    }

    private func handleWorkspaceDidActivateApplication(_ notification: Notification) {
        guard Self.activeController === self else { return }
        let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        guard let activeClientBundleIdentifier,
              activatedApp?.bundleIdentifier != activeClientBundleIdentifier else {
            return
        }
        abandonComposition()
    }

    private func updateComposition(client: IMKTextInput) {
        guard hasComposition, let cyrillic = engine.mappedText(for: rawInput) else {
            clearComposition(client: client)
            return
        }

        currentCandidates = engine.candidates(for: rawInput, previousWord: previousCommittedWord, limit: currentCandidateLimit)
        clampHighlightedCandidateIndex()
        syncPageToHighlightedCandidate()

        let markedAttributes: [NSAttributedString.Key: Any]
        switch PreferencesStore.shared.preferences.sanitized.preeditStyle {
        case .underline:
            markedAttributes = [
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        case .filled:
            markedAttributes = [
                .backgroundColor: NSColor.controlAccentColor.withAlphaComponent(0.18),
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        case .minimal:
            markedAttributes = [:]
        }

        client.setMarkedText(
            NSAttributedString(string: cyrillic, attributes: markedAttributes),
            selectionRange: NSRange(location: cyrillic.count, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )

        candidateWindow.show(
            composition: cyrillic,
            candidates: Array(visibleCandidates()),
            highlightedIndex: localHighlightedCandidateIndex,
            pageLabel: pageLabelText,
            cursorRect: cursorScreenRect(for: client, compositionLength: cyrillic.count)
        )
    }

    private func commitBestCandidate(client: IMKTextInput) {
        let text = currentCandidates.first?.text ?? engine.mappedText(for: rawInput) ?? rawInput
        commit(text, client: client)
    }

    private func commit(_ text: String, client: IMKTextInput) {
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        previousCommittedWord = normalizedCommittedWord(from: text)
        clearComposition(client: client)
    }

    private func cancelComposition(client: IMKTextInput) {
        client.setMarkedText(
            "",
            selectionRange: NSRange(location: 0, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )
        clearComposition(client: client)
    }

    private func clearComposition(client: IMKTextInput) {
        resetCompositionState()
        client.setMarkedText(
            "",
            selectionRange: NSRange(location: 0, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )
    }

    private func abandonComposition() {
        if let client = client(), hasComposition {
            client.setMarkedText(
                "",
                selectionRange: NSRange(location: 0, length: 0),
                replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
            )
        }
        resetCompositionState()
        if Self.activeController === self {
            Self.activeController = nil
        }
    }

    private func resetCompositionState() {
        rawInput.removeAll()
        currentCandidates.removeAll()
        highlightedCandidateIndex = 0
        currentPageIndex = 0
        temporaryEnglishActive = false
        standaloneShiftState.cancel()
        modeToastTask?.cancel()
        modeToastTask = nil
        candidateWindow.hide()
        updateInputModeLabel()
    }

    private func candidateIndex(for event: NSEvent) -> Int? {
        guard let ch = event.charactersIgnoringModifiers, ch.count == 1 else { return nil }
        switch ch {
        case "1": return 0
        case "2": return 1
        case "3": return 2
        case "4": return 3
        case "5": return 4
        case "6": return 5
        case "7": return 6
        case "8": return 7
        default:  return nil
        }
    }

    private func cursorScreenRect(for client: IMKTextInput, compositionLength: Int) -> NSRect? {
        for index in preferredCharacterIndexes(compositionLength: compositionLength) {
            var lineRect = NSRect.zero
            _ = client.attributes(forCharacterIndex: index, lineHeightRectangle: &lineRect)
            if let normalizedRect = normalizedCursorRect(lineRect) {
                return normalizedRect
            }
        }

        for range in preferredCursorRanges(for: client) {
            let rect = client.firstRect(forCharacterRange: range, actualRange: nil)
            if let normalizedRect = normalizedCursorRect(rect) {
                return normalizedRect
            }
        }

        return nil
    }

    private func preferredCharacterIndexes(compositionLength: Int) -> [Int] {
        guard compositionLength > 0 else { return [0] }
        return [compositionLength, max(compositionLength - 1, 0), 0]
    }

    private func preferredCursorRanges(for client: IMKTextInput) -> [NSRange] {
        var ranges: [NSRange] = []

        let selectedRange = client.selectedRange()
        if selectedRange.location != NSNotFound {
            ranges.append(NSRange(location: selectedRange.location + selectedRange.length, length: 0))
            ranges.append(selectedRange)
        }

        let markedRange = client.markedRange()
        if markedRange.location != NSNotFound {
            ranges.append(NSRange(location: markedRange.location + markedRange.length, length: 0))
            ranges.append(markedRange)
        }

        return ranges
    }

    private func normalizedCursorRect(_ rect: NSRect) -> NSRect? {
        let normalized = rect.standardized
        guard !normalized.isEmpty,
              normalized.origin.x.isFinite,
              normalized.origin.y.isFinite,
              normalized.width.isFinite,
              normalized.height.isFinite,
              normalized.height > 0 else {
            return nil
        }

        return NSRect(
            x: normalized.minX,
            y: normalized.minY,
            width: max(normalized.width, 1),
            height: normalized.height
        )
    }

    private func selectCandidate(at index: Int) {
        guard hasComposition,
              let actualIndex = candidateIndexInCurrentPage(localIndex: index),
              currentCandidates.indices.contains(actualIndex),
              let client = client() else { return }
        commitCandidate(at: actualIndex, client: client)
    }

    private func commitSelectedCandidate(client: IMKTextInput) {
        guard hasComposition else { return }
        clampHighlightedCandidateIndex()
        if currentCandidates.indices.contains(highlightedCandidateIndex) {
            commitCandidate(at: highlightedCandidateIndex, client: client)
            return
        }

        let text = currentCandidates.first?.text ?? engine.mappedText(for: rawInput) ?? rawInput
        commit(text, client: client)
    }

    private func moveSelection(by delta: Int) {
        guard !currentCandidates.isEmpty else { return }
        highlightedCandidateIndex = (highlightedCandidateIndex + delta + currentCandidates.count) % currentCandidates.count
        syncPageToHighlightedCandidate()
        refreshCandidateWindow()
    }

    private func movePage(by delta: Int) {
        guard pageCount > 1 else { return }

        let nextPage = min(max(currentPageIndex + delta, 0), pageCount - 1)
        guard nextPage != currentPageIndex else { return }

        currentPageIndex = nextPage
        let pageRange = currentPageRange
        highlightedCandidateIndex = min(pageRange.lowerBound, currentCandidates.count - 1)
        refreshCandidateWindow()
    }

    private func clampHighlightedCandidateIndex() {
        if currentCandidates.isEmpty {
            highlightedCandidateIndex = 0
        } else {
            highlightedCandidateIndex = min(highlightedCandidateIndex, currentCandidates.count - 1)
        }
    }

    private func handleFlagsChanged(_ event: NSEvent, sender: Any!) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let previousFlags = lastModifierFlags
        lastModifierFlags = flags

        let shiftWasDown = previousFlags.contains(.shift)
        let shiftIsDown = flags.contains(.shift)
        let nonShiftFlags = flags.subtracting(.shift)
        let previousNonShiftFlags = previousFlags.subtracting(.shift)
        let isShiftKey = event.keyCode == 56 || event.keyCode == 60

        if standaloneShiftState.isPending,
           nonShiftFlags != previousNonShiftFlags || !nonShiftFlags.isEmpty {
            standaloneShiftState.noteOtherModifier()
        }

        if isShiftKey && !shiftWasDown && shiftIsDown {
            standaloneShiftState.begin(with: event.keyCode)
            if !nonShiftFlags.isEmpty {
                standaloneShiftState.noteOtherModifier()
            }
            return true
        }

        if isShiftKey && shiftWasDown && !shiftIsDown {
            let shouldToggle = standaloneShiftState.shouldToggle(on: event.keyCode)
            standaloneShiftState.cancel()
            if shouldToggle {
                toggleEnglishMode(sender: sender)
            }
            return true
        }

        if !shiftIsDown {
            standaloneShiftState.cancel()
        }

        return false
    }

    private func commitCandidate(at index: Int, client: IMKTextInput) {
        guard currentCandidates.indices.contains(index) else { return }

        highlightedCandidateIndex = index
        let selectedText = currentCandidates[index].text
        let selectedInput = rawInput
        engine.learnSelection(selectedText, for: selectedInput, previousWord: previousCommittedWord)
        commit(selectedText, client: client)
    }

    private func toggleEnglishMode(sender: Any!) {
        let nextMode: InputMode = inputMode == .russian ? .english : .russian
        setInputMode(nextMode, sender: sender)
        if let client = sender as? IMKTextInput, hasComposition {
            commitSelectedCandidate(client: client)
        }
    }

    private func setInputMode(_ mode: InputMode, sender: Any!) {
        inputMode = mode
        persistInputMode(for: sender)
        updateInputModeLabel()
        maybeShowModeToast()
    }

    private var effectiveInputMode: InputMode {
        temporaryEnglishActive ? .english : inputMode
    }

    private func updateInputModeLabel() {
        candidateWindow.setInputModeLabel(effectiveInputMode == .english ? "EN" : "RU")
    }

    private func maybeShowModeToast() {
        let preferences = PreferencesStore.shared.preferences.sanitized
        guard preferences.showShiftModeToast else { return }
        modeToastTask?.cancel()
        candidateWindow.showToast(effectiveInputMode == .english ? "英文直通" : "俄语输入")
        let task = DispatchWorkItem { [weak self] in
            guard let self, self.hasComposition else { return }
            self.refreshCandidateWindow()
        }
        modeToastTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65, execute: task)
    }

    private func persistInputMode(for sender: Any!) {
        let preferences = PreferencesStore.shared.preferences.sanitized
        guard preferences.persistInputModeState else { return }

        var state = PreferencesStore.shared.loadInputModeState()
        state.globalMode = inputMode == .english ? "english" : "russian"

        if preferences.rememberModePerApp,
           let appId = appContext(for: sender).bundleIdentifier {
            state.appModes[appId] = state.globalMode
        }

        PreferencesStore.shared.saveInputModeState(state)
    }

    private func restoreInputMode(for sender: Any!) {
        let preferences = PreferencesStore.shared.preferences.sanitized
        guard preferences.persistInputModeState else {
            inputMode = .russian
            temporaryEnglishActive = false
            return
        }

        let state = PreferencesStore.shared.loadInputModeState()
        let appId = appContext(for: sender).bundleIdentifier

        let storedMode: String
        if preferences.rememberModePerApp,
           let appId,
           let mode = state.appModes[appId] {
            storedMode = mode
        } else {
            storedMode = state.globalMode
        }

        inputMode = storedMode == "english" ? .english : .russian
    }

    private func appContext(for sender: Any!) -> AppContext {
        let clientBundleIdentifier: String?
        let bundleIdentifierSelector = NSSelectorFromString("bundleIdentifier")
        if let object = sender as? NSObject,
           object.responds(to: bundleIdentifierSelector),
           let bundleIdentifier = object.value(forKey: "bundleIdentifier") as? String {
            clientBundleIdentifier = bundleIdentifier
        } else {
            clientBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        }
        return AppContext(bundleIdentifier: clientBundleIdentifier)
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

    private var localHighlightedCandidateIndex: Int {
        max(0, highlightedCandidateIndex - currentPageRange.lowerBound)
    }

    private var pageLabelText: String {
        guard pageCount > 1 else { return "" }
        return "\(currentPageIndex + 1)/\(pageCount)"
    }

    private func visibleCandidates() -> ArraySlice<InputEngine.Candidate> {
        guard !currentCandidates.isEmpty else { return [] }
        return currentCandidates[currentPageRange]
    }

    private func candidateIndexInCurrentPage(localIndex: Int) -> Int? {
        let actualIndex = currentPageRange.lowerBound + localIndex
        return currentCandidates.indices.contains(actualIndex) ? actualIndex : nil
    }

    private func syncPageToHighlightedCandidate() {
        guard !currentCandidates.isEmpty else {
            currentPageIndex = 0
            return
        }
        currentPageIndex = highlightedCandidateIndex / Self.candidatePageSize
    }

    private func refreshCandidateWindow() {
        candidateWindow.show(
            composition: engine.mappedText(for: rawInput) ?? rawInput,
            candidates: Array(visibleCandidates()),
            highlightedIndex: localHighlightedCandidateIndex,
            pageLabel: pageLabelText,
            cursorRect: client().flatMap { cursorScreenRect(for: $0, compositionLength: (engine.mappedText(for: rawInput) ?? rawInput).count) }
        )
    }

    private var currentCandidateLimit: Int {
        PreferencesStore.shared.preferences.sanitized.maxCandidateCount
    }

    private func handlePreferencesDidChange() {
        engine.updatePreferences(PreferencesStore.shared.preferences)
        restoreInputMode(for: client())
        updateInputModeLabel()
        if hasComposition,
           let client = client() as? IMKTextInput {
            updateComposition(client: client)
        } else {
            candidateWindow.reloadTheme()
        }
    }

    private func handleLearningDataDidReset() {
        engine.replaceUserLexicon(UserLexiconStore())
        if hasComposition,
           let client = client() {
            updateComposition(client: client)
        }
    }

    private func normalizedCommittedWord(from text: String) -> String? {
        let trimmed = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func assertMainThread() {
        dispatchPrecondition(condition: .onQueue(.main))
    }
}
