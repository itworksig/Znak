import AppKit

final class PreferencesWindowController: NSWindowController {
    private let store: PreferencesStore

    private let themePopup = NSPopUpButton()
    private let builtinDictionaryCheckbox = NSButton(checkboxWithTitle: "启用内置词库", target: nil, action: nil)
    private let customDictionaryCheckbox = NSButton(checkboxWithTitle: "启用自定义词库", target: nil, action: nil)
    private let predictionCheckbox = NSButton(checkboxWithTitle: "启用联想/学习排序", target: nil, action: nil)
    private let learningCheckbox = NSButton(checkboxWithTitle: "记住用户选词习惯", target: nil, action: nil)
    private let correctionCheckbox = NSButton(checkboxWithTitle: "启用纠错/模糊匹配", target: nil, action: nil)
    private let perAppModeCheckbox = NSButton(checkboxWithTitle: "按应用记住 RU/EN 模式", target: nil, action: nil)
    private let temporaryEnglishCheckbox = NSButton(checkboxWithTitle: "按住 Shift 临时英文输入", target: nil, action: nil)
    private let persistModeCheckbox = NSButton(checkboxWithTitle: "记住输入模式状态", target: nil, action: nil)
    private let shiftToastCheckbox = NSButton(checkboxWithTitle: "切换模式时显示轻提示", target: nil, action: nil)
    private let capsLockPopup = NSPopUpButton()
    private let preeditStylePopup = NSPopUpButton()
    private let candidateDetailsCheckbox = NSButton(checkboxWithTitle: "显示候选注释/词性/来源", target: nil, action: nil)
    private let candidateDebugCheckbox = NSButton(checkboxWithTitle: "显示候选来源与排序解释", target: nil, action: nil)
    private let candidateAnimationsCheckbox = NSButton(checkboxWithTitle: "启用候选窗动画与轻提示", target: nil, action: nil)
    private let candidateCountField = NSTextField()
    private let customDictionaryView = NSTextView()
    private let learnedPreviewView = NSTextView()

    init(store: PreferencesStore = .shared) {
        self.store = store

        let contentRect = NSRect(x: 0, y: 0, width: 760, height: 680)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Znak Settings"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        buildUI()
        loadPreferences()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindowAndActivate() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 18
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18)
        ])

        themePopup.addItems(withTitles: ZnakThemePreset.allCases.map(\.displayName))
        capsLockPopup.addItems(withTitles: InputPreferences.CapsLockBehavior.allCases.map(\.displayName))
        preeditStylePopup.addItems(withTitles: InputPreferences.PreeditStyle.allCases.map(\.displayName))
        candidateCountField.alignment = .right
        candidateCountField.controlSize = .regular

        let appearanceSection = makeSection(title: "外观", views: [
            makeLabeledRow(label: "候选窗主题", control: themePopup),
            makeLabeledRow(label: "预编辑样式", control: preeditStylePopup),
            candidateDetailsCheckbox,
            candidateDebugCheckbox,
            candidateAnimationsCheckbox,
            makeLabeledRow(label: "每次最多候选数", control: candidateCountField)
        ])

        let intelligenceSection = makeSection(title: "智能输入", views: [
            builtinDictionaryCheckbox,
            customDictionaryCheckbox,
            predictionCheckbox,
            learningCheckbox,
            correctionCheckbox,
            makeLabeledRow(label: "Caps Lock 行为", control: capsLockPopup),
            perAppModeCheckbox,
            temporaryEnglishCheckbox,
            persistModeCheckbox,
            shiftToastCheckbox
        ])

        let customDictionarySection = makeDictionarySection(
            title: "自定义词库",
            textView: customDictionaryView,
            buttonTitle: "保存自定义词库",
            buttonAction: #selector(savePreferences)
        )

        let learnedSection = makeDictionarySection(
            title: "用户学习词典预览",
            textView: learnedPreviewView,
            buttonTitle: "清空学习记录",
            buttonAction: #selector(resetLearningData)
        )
        learnedPreviewView.isEditable = false

        let footerButtons = NSStackView()
        footerButtons.orientation = .horizontal
        footerButtons.alignment = .centerY
        footerButtons.spacing = 12

        let saveButton = NSButton(title: "应用设置", target: self, action: #selector(savePreferences))
        saveButton.bezelStyle = .rounded
        let reloadButton = NSButton(title: "重新读取", target: self, action: #selector(reloadPreferences))
        reloadButton.bezelStyle = .rounded
        footerButtons.addArrangedSubview(saveButton)
        footerButtons.addArrangedSubview(reloadButton)
        footerButtons.addArrangedSubview(NSView())

        [appearanceSection, intelligenceSection, customDictionarySection, learnedSection, footerButtons].forEach {
            root.addArrangedSubview($0)
        }
    }

    private func makeSection(title: String, views: [NSView]) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)

        let stack = NSStackView(views: [titleLabel] + views)
        stack.orientation = .vertical
        stack.spacing = 10
        return wrapInCard(stack)
    }

    private func makeDictionarySection(title: String, textView: NSTextView, buttonTitle: String, buttonAction: Selector) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)

        let scrollView = NSScrollView()
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isRichText = false
        textView.usesFindBar = true
        textView.minSize = NSSize(width: 0, height: 180)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 8, height: 8)

        NSLayoutConstraint.activate([
            scrollView.heightAnchor.constraint(equalToConstant: 180)
        ])

        let actionButton = NSButton(title: buttonTitle, target: self, action: buttonAction)
        actionButton.bezelStyle = .rounded

        let stack = NSStackView(views: [titleLabel, scrollView, actionButton])
        stack.orientation = .vertical
        stack.spacing = 10
        return wrapInCard(stack)
    }

    private func makeLabeledRow(label: String, control: NSView) -> NSView {
        let labelField = NSTextField(labelWithString: label)
        labelField.font = .systemFont(ofSize: 13)

        let row = NSStackView(views: [labelField, NSView(), control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func wrapInCard(_ content: NSView) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 14
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92).cgColor
        container.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.4).cgColor
        container.layer?.borderWidth = 1

        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14)
        ])
        return container
    }

    private func loadPreferences() {
        let preferences = store.preferences
        themePopup.selectItem(at: ZnakThemePreset.allCases.firstIndex(of: preferences.themePreset) ?? 0)
        builtinDictionaryCheckbox.state = preferences.enableBuiltinDictionary ? .on : .off
        customDictionaryCheckbox.state = preferences.enableCustomDictionary ? .on : .off
        predictionCheckbox.state = preferences.enablePrediction ? .on : .off
        learningCheckbox.state = preferences.enableLearning ? .on : .off
        correctionCheckbox.state = preferences.enableAutoCorrection ? .on : .off
        capsLockPopup.selectItem(at: InputPreferences.CapsLockBehavior.allCases.firstIndex(of: preferences.capsLockBehavior) ?? 0)
        preeditStylePopup.selectItem(at: InputPreferences.PreeditStyle.allCases.firstIndex(of: preferences.preeditStyle) ?? 0)
        perAppModeCheckbox.state = preferences.rememberModePerApp ? .on : .off
        temporaryEnglishCheckbox.state = preferences.enableTemporaryEnglishMode ? .on : .off
        persistModeCheckbox.state = preferences.persistInputModeState ? .on : .off
        shiftToastCheckbox.state = preferences.showShiftModeToast ? .on : .off
        candidateDetailsCheckbox.state = preferences.showCandidateDetails ? .on : .off
        candidateDebugCheckbox.state = preferences.showCandidateDebugInfo ? .on : .off
        candidateAnimationsCheckbox.state = preferences.enableCandidateAnimations ? .on : .off
        candidateCountField.stringValue = "\(preferences.maxCandidateCount)"
        customDictionaryView.string = preferences.customDictionaryText
        learnedPreviewView.string = store.learnedDictionaryPreview()
    }

    @objc
    private func savePreferences() {
        let theme = ZnakThemePreset.allCases[safe: themePopup.indexOfSelectedItem] ?? .sogou
        let capsLockBehavior = InputPreferences.CapsLockBehavior.allCases[safe: capsLockPopup.indexOfSelectedItem] ?? .passthrough
        let preeditStyle = InputPreferences.PreeditStyle.allCases[safe: preeditStylePopup.indexOfSelectedItem] ?? .underline
        let count = Int(candidateCountField.stringValue) ?? InputPreferences.default.maxCandidateCount
        let preferences = InputPreferences(
            themePreset: theme,
            enableBuiltinDictionary: builtinDictionaryCheckbox.state == .on,
            enableCustomDictionary: customDictionaryCheckbox.state == .on,
            enablePrediction: predictionCheckbox.state == .on,
            enableLearning: learningCheckbox.state == .on,
            enableAutoCorrection: correctionCheckbox.state == .on,
            maxCandidateCount: count,
            customDictionaryText: customDictionaryView.string,
            capsLockBehavior: capsLockBehavior,
            rememberModePerApp: perAppModeCheckbox.state == .on,
            enableTemporaryEnglishMode: temporaryEnglishCheckbox.state == .on,
            persistInputModeState: persistModeCheckbox.state == .on,
            showShiftModeToast: shiftToastCheckbox.state == .on,
            preeditStyle: preeditStyle,
            showCandidateDetails: candidateDetailsCheckbox.state == .on,
            showCandidateDebugInfo: candidateDebugCheckbox.state == .on,
            enableCandidateAnimations: candidateAnimationsCheckbox.state == .on
        ).sanitized

        store.preferences = preferences
        learnedPreviewView.string = store.learnedDictionaryPreview()
    }

    @objc
    private func reloadPreferences() {
        loadPreferences()
    }

    @objc
    private func resetLearningData() {
        store.resetLearningData()
        learnedPreviewView.string = store.learnedDictionaryPreview()
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
