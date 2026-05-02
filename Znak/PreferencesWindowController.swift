@preconcurrency import AppKit
import UniformTypeIdentifiers

final class PreferencesWindowController: NSWindowController {
    private static let defaultWindowSize = NSSize(width: 980, height: 820)
    private static let minimumWindowSize = NSSize(width: 920, height: 760)
    private static let maxWindowSize = NSSize(width: 1600, height: 1400)
    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/itworksig/Znak/releases/latest")!

    private struct GitHubRelease: Decodable {
        let tagName: String
        let assets: [GitHubReleaseAsset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case assets
        }
    }

    private struct GitHubReleaseAsset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    private let store: PreferencesStore

    private let themePopup = NSPopUpButton()
    private let builtinDictionaryCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let customDictionaryCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let predictionCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let latinPredictionCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let learningCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let correctionCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let perAppModeCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let temporaryEnglishCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let persistModeCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let shiftToastCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let capsLockPopup = NSPopUpButton()
    private let preeditStylePopup = NSPopUpButton()
    private let rankingPopup = NSPopUpButton()
    private let candidateLayoutPopup = NSPopUpButton()
    private let candidateDetailsCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let candidateDebugCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let candidateAnimationsCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let candidateCountField = NSTextField()
    private let candidateFontSizeField = NSTextField()
    private let customDictionaryView = NSTextView()
    private let learnedPreviewView = NSTextView()
    private let subtitleLabel = NSTextField(labelWithString: "候选窗主题、词库与输入行为都可以在这里统一调整。\nТема окна кандидатов, словари и поведение ввода.\nTune candidate theme, dictionaries, and input behavior here.")
    private let versionLabel = NSTextField(labelWithString: "")
    private var learningDiagnosticObserver: NSObjectProtocol?

    init(store: PreferencesStore = .shared) {
        self.store = store

        let contentRect = NSRect(origin: .zero, size: Self.defaultWindowSize)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Znak"
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unifiedCompact
        window.setContentSize(Self.defaultWindowSize)
        window.contentMinSize = Self.minimumWindowSize
        window.contentMaxSize = Self.maxWindowSize
        window.minSize = Self.minimumWindowSize
        window.maxSize = Self.maxWindowSize
        window.setFrameAutosaveName("")

        super.init(window: window)
        buildUI()
        loadPreferences()
        learningDiagnosticObserver = NotificationCenter.default.addObserver(
            forName: .znakLearningDataDiagnosticDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.learnedPreviewView.string = self?.store.learnedDictionaryPreview() ?? ""
            }
        }
    }

    deinit {
        if let learningDiagnosticObserver {
            NotificationCenter.default.removeObserver(learningDiagnosticObserver)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindowAndActivate() {
        showWindow(nil)
        forceWindowFrame()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func forceWindowFrame() {
        guard let window else { return }
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: Self.defaultWindowSize))
        window.minSize = Self.minimumWindowSize
        window.maxSize = Self.maxWindowSize
        if let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
            frame.origin.x = screenFrame.midX - frame.width / 2
            frame.origin.y = screenFrame.midY - frame.height / 2
        }
        window.setContentSize(Self.defaultWindowSize)
        window.setFrame(frame, display: true, animate: false)
        window.layoutIfNeeded()
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let background = NSView()
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor.white.cgColor
        background.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(background)

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(scrollView)

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .centerX
        root.distribution = .fill
        root.spacing = 24
        root.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(root)

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            background.topAnchor.constraint(equalTo: contentView.topAnchor),
            background.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: background.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: background.bottomAnchor),

            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            documentView.widthAnchor.constraint(greaterThanOrEqualToConstant: Self.minimumWindowSize.width),
            root.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 28),
            root.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -28),
            root.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 24),
            root.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -28)
        ])

        configureControls()

        let hero = makeHeroSection()
        let topGrid = makeTopSection()
        let dictionaries = makeLargeDictionarySection()
        let footer = makeFooterBar()

        [hero, topGrid, dictionaries, footer].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            root.addArrangedSubview($0)
        }

        NSLayoutConstraint.activate([
            hero.widthAnchor.constraint(equalTo: root.widthAnchor),
            topGrid.widthAnchor.constraint(equalTo: root.widthAnchor),
            dictionaries.widthAnchor.constraint(equalTo: root.widthAnchor),
            footer.widthAnchor.constraint(equalTo: root.widthAnchor)
        ])
    }

    private func makeTopSection() -> NSView {
        let firstRow = makeEqualWidthRow(makeAppearanceCard(), makeInputModeCard())
        let secondRow = makeEqualWidthRow(makeLexiconCard(), makeLearningCard())

        let stack = NSStackView(views: [firstRow, secondRow])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 18
        return stack
    }

    private func configureControls() {
        themePopup.addItems(withTitles: ZnakThemePreset.allCases.map(\.displayName))
        capsLockPopup.addItems(withTitles: InputPreferences.CapsLockBehavior.allCases.map(\.displayName))
        preeditStylePopup.addItems(withTitles: InputPreferences.PreeditStyle.allCases.map(\.displayName))
        rankingPopup.addItems(withTitles: InputPreferences.CandidateRankingPreference.allCases.map(\.displayName))
        candidateLayoutPopup.addItems(withTitles: InputPreferences.CandidateLayout.allCases.map(\.displayName))

        [themePopup, capsLockPopup, preeditStylePopup, rankingPopup, candidateLayoutPopup].forEach {
            $0.controlSize = .large
            $0.font = .systemFont(ofSize: 13, weight: .medium)
        }

        [candidateCountField, candidateFontSizeField].forEach { field in
            field.alignment = .center
            field.controlSize = .large
            field.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
            field.wantsLayer = true
            field.layer?.cornerRadius = 10
        }

        [builtinDictionaryCheckbox, customDictionaryCheckbox, predictionCheckbox, latinPredictionCheckbox, learningCheckbox, correctionCheckbox,
         perAppModeCheckbox, temporaryEnglishCheckbox, persistModeCheckbox, shiftToastCheckbox,
         candidateDetailsCheckbox, candidateDebugCheckbox, candidateAnimationsCheckbox].forEach {
            $0.font = .systemFont(ofSize: 14, weight: .medium)
            $0.setButtonType(.switch)
            $0.controlSize = .large
            $0.title = ""
        }

        [customDictionaryView, learnedPreviewView].forEach {
            $0.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            $0.isRichText = false
            $0.usesFindBar = true
            $0.minSize = NSSize(width: 0, height: 220)
            $0.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            $0.isVerticallyResizable = true
            $0.isHorizontallyResizable = false
            $0.textContainerInset = NSSize(width: 10, height: 12)
            $0.backgroundColor = .white
        }
        learnedPreviewView.isEditable = false
    }

    private func makeHeroSection() -> NSView {
        let title = NSTextField(labelWithString: "Znak")
        title.font = .systemFont(ofSize: 30, weight: .bold)
        title.textColor = .labelColor

        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 3

        versionLabel.stringValue = Self.appVersionDisplayText
        versionLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.maximumNumberOfLines = 1

        let badges = NSStackView(views: [
            makeBadge(title: "RU/EN", tint: NSColor.systemBlue),
            makeBadge(title: "词库 / Словарь / Lexicon", tint: NSColor.systemOrange),
            makeBadge(title: "候选窗 / Кандидаты / Candidates", tint: NSColor.systemTeal),
            makeBadge(title: Self.appVersionDisplayText, tint: NSColor.systemGray)
        ])
        badges.orientation = .horizontal
        badges.spacing = 10

        let headerRow = NSStackView(views: [title, NSView(), versionLabel])
        headerRow.orientation = .horizontal
        headerRow.alignment = .firstBaseline
        headerRow.spacing = 12

        let stack = NSStackView(views: [headerRow, subtitleLabel, badges])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 10
        return wrapInCard(content: stack, inset: 22, accent: true)
    }

    private static var appVersionDisplayText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String

        switch (version?.isEmpty == false ? version : nil, build?.isEmpty == false ? build : nil) {
        case let (.some(version), .some(build)):
            return "v\(version) (\(build))"
        case let (.some(version), nil):
            return "v\(version)"
        case (nil, let .some(build)):
            return "build \(build)"
        default:
            return "version unknown"
        }
    }

    private func makeAppearanceCard() -> NSView {
        let stack = cardStack(
            title: "候选窗外观",
            subtitle: "Внешний вид окна кандидатов / Candidate appearance\n控制主题、预编辑和信息密度。"
        )
        stack.addArrangedSubview(makeSettingRow("候选窗主题", "Тема окна / Window theme", themePopup))
        stack.addArrangedSubview(makeSettingRow("预编辑样式", "Стиль предредактирования / Preedit style", preeditStylePopup))
        stack.addArrangedSubview(makeSettingRow("候选排序偏好", "Приоритет кандидатов / Candidate priority", rankingPopup))
        stack.addArrangedSubview(makeSettingRow("候选窗布局", "Макет окна / Candidate layout", candidateLayoutPopup))
        stack.addArrangedSubview(makeSettingRow("每页最多候选数", "Кандидатов на страницу / Candidates per page", candidateCountField))
        stack.addArrangedSubview(makeSettingRow("候选字号", "Размер шрифта / Candidate font size", candidateFontSizeField))
        stack.addArrangedSubview(makeCheckboxRow(candidateDetailsCheckbox, title: "显示候选注释 / 词性 / 来源", subtitle: "Примечания, часть речи, источник / Note, POS, source"))
        stack.addArrangedSubview(makeCheckboxRow(candidateDebugCheckbox, title: "显示候选来源与排序解释", subtitle: "Источник и ранжирование / Source and ranking explanation"))
        stack.addArrangedSubview(makeCheckboxRow(candidateAnimationsCheckbox, title: "启用候选窗动画与轻提示", subtitle: "Анимация и подсказки / Candidate animations and toast"))
        return wrapInCard(content: stack, inset: 20)
    }

    private func makeInputModeCard() -> NSView {
        let stack = cardStack(
            title: "输入模式",
            subtitle: "Режим ввода / Input mode\n决定中英切换、Caps Lock 和状态记忆方式。"
        )
        stack.addArrangedSubview(makeSettingRow("Caps Lock 行为", "Поведение Caps Lock / Caps Lock behavior", capsLockPopup))
        stack.addArrangedSubview(makeCheckboxRow(perAppModeCheckbox, title: "按应用记住 RU/EN 模式", subtitle: "По приложениям / Remember RU/EN per app"))
        stack.addArrangedSubview(makeCheckboxRow(temporaryEnglishCheckbox, title: "按住 Shift 临时英文输入", subtitle: "Временный English / Temporary English with Shift"))
        stack.addArrangedSubview(makeCheckboxRow(persistModeCheckbox, title: "记住输入模式状态", subtitle: "Сохранять режим / Persist input mode state"))
        stack.addArrangedSubview(makeCheckboxRow(shiftToastCheckbox, title: "切换模式时显示轻提示", subtitle: "Подсказка режима / Show mode switch toast"))
        return wrapInCard(content: stack, inset: 20)
    }

    private func makeLexiconCard() -> NSView {
        let stack = cardStack(
            title: "词库开关",
            subtitle: "Источники словаря / Dictionary sources\n控制系统词库、自定义词库与纠错能力。"
        )
        stack.addArrangedSubview(makeCheckboxRow(builtinDictionaryCheckbox, title: "启用内置词库", subtitle: "Встроенный словарь / Built-in dictionary"))
        stack.addArrangedSubview(makeCheckboxRow(customDictionaryCheckbox, title: "启用自定义词库", subtitle: "Пользовательский словарь / Custom dictionary"))
        stack.addArrangedSubview(makeCheckboxRow(correctionCheckbox, title: "启用纠错/模糊匹配", subtitle: "Исправление и нечёткий поиск / Auto-correction and fuzzy match"))
        return wrapInCard(content: stack, inset: 20)
    }

    private func makeLearningCard() -> NSView {
        let stack = cardStack(
            title: "学习与联想",
            subtitle: "Обучение и подсказки / Learning and prediction\n决定输入法是否根据你的选择自动调整排序。"
        )
        stack.addArrangedSubview(makeCheckboxRow(predictionCheckbox, title: "启用智能联想排序", subtitle: "Умные подсказки / Smart prediction ranking"))
        stack.addArrangedSubview(makeCheckboxRow(latinPredictionCheckbox, title: "启用拉丁联想", subtitle: "Латинские подсказки / Latin transliteration prediction"))
        stack.addArrangedSubview(makeCheckboxRow(learningCheckbox, title: "记住用户选词习惯", subtitle: "Запоминать выбор / Learn from candidate selection"))
        return wrapInCard(content: stack, inset: 20)
    }

    private func makeLargeDictionarySection() -> NSView {
        let title = NSTextField(labelWithString: "词库与学习数据")
        title.font = .systemFont(ofSize: 20, weight: .bold)

        let subtitle = NSTextField(labelWithString: "Словари и данные обучения / Lexicon and learning data\n自定义词库用于长期补充，学习词典预览用于调试排序与用户习惯。")
        subtitle.font = .systemFont(ofSize: 13, weight: .regular)
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 2

        let customSection = makeEditorCard(
            title: "自定义词库",
            subtitle: "Пользовательский словарь / Custom dictionary\n每行一个词，可附频率，例如：`привет 520`",
            textView: customDictionaryView,
            primaryActionTitle: "保存自定义词库 / Save / Сохранить",
            primaryAction: #selector(savePreferences),
            secondaryActions: [
                ("导入 / Import", #selector(importCustomDictionary)),
                ("导出 / Export", #selector(exportCustomDictionary))
            ]
        )

        let learnedSection = makeEditorCard(
            title: "用户学习词典预览",
            subtitle: "Просмотр обученного словаря / Learned dictionary preview\n查看学习到的排序数据，必要时可以一键清空。",
            textView: learnedPreviewView,
            primaryActionTitle: "清空学习记录 / Reset / Очистить",
            primaryAction: #selector(resetLearningData)
        )

        let grid = makeEqualWidthRow(customSection, learnedSection)

        let stack = NSStackView(views: [title, subtitle, grid])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        return stack
    }

    private func makeEqualWidthRow(_ left: NSView, _ right: NSView) -> NSView {
        left.translatesAutoresizingMaskIntoConstraints = false
        right.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [left, right])
        row.orientation = .horizontal
        row.alignment = .top
        row.distribution = .fillEqually
        row.spacing = 18
        row.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            left.widthAnchor.constraint(greaterThanOrEqualToConstant: 320),
            right.widthAnchor.constraint(greaterThanOrEqualToConstant: 320)
        ])
        return row
    }

    private func makeEditorCard(title: String, subtitle: String, textView: NSTextView, primaryActionTitle: String, primaryAction: Selector, secondaryActions: [(String, Selector)] = []) -> NSView {
        let titleField = NSTextField(labelWithString: title)
        titleField.font = .systemFont(ofSize: 16, weight: .semibold)

        let subtitleField = NSTextField(labelWithString: subtitle)
        subtitleField.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleField.textColor = .secondaryLabelColor

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 14
        scrollView.layer?.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.8).cgColor
        scrollView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        scrollView.layer?.borderWidth = 1
        scrollView.documentView = textView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.heightAnchor.constraint(equalToConstant: 260)
        ])

        let actionButton = makeProminentButton(title: primaryActionTitle, action: primaryAction)
        let actionRow = NSStackView(views: [actionButton] + secondaryActions.map { title, selector in
            let button = NSButton(title: title, target: self, action: selector)
            button.bezelStyle = .rounded
            button.controlSize = .large
            return button
        })
        actionRow.orientation = .horizontal
        actionRow.spacing = 10
        let stack = NSStackView(views: [titleField, subtitleField, scrollView, actionRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        return wrapInCard(content: stack, inset: 18)
    }

    private func makeFooterBar() -> NSView {
        let saveButton = makeProminentButton(title: "应用设置 / Apply / Применить", action: #selector(savePreferences))
        let reloadButton = NSButton(title: "重新读取 / Reload / Перезагрузить", target: self, action: #selector(reloadPreferences))
        reloadButton.bezelStyle = .rounded
        reloadButton.controlSize = .large

        let updateButton = NSButton(title: "检查更新 / Releases", target: self, action: #selector(openReleasesPage))
        updateButton.bezelStyle = .rounded
        updateButton.controlSize = .large

        let hint = NSTextField(labelWithString: "改动会立即同步到候选窗与输入行为。\nИзменения сразу применяются к окну кандидатов и логике ввода.\nChanges apply immediately to the candidate window and input behavior.")
        hint.font = .systemFont(ofSize: 12, weight: .regular)
        hint.textColor = .secondaryLabelColor
        hint.maximumNumberOfLines = 3

        let left = NSStackView(views: [hint])
        left.orientation = .vertical

        let right = NSStackView(views: [updateButton, reloadButton, saveButton])
        right.orientation = .horizontal
        right.spacing = 10

        let row = NSStackView(views: [left, NSView(), right])
        row.orientation = .horizontal
        row.alignment = .centerY
        return row
    }

    private func cardStack(title: String, subtitle: String) -> NSStackView {
        let titleField = NSTextField(labelWithString: title)
        titleField.font = .systemFont(ofSize: 17, weight: .bold)

        let subtitleField = NSTextField(labelWithString: subtitle)
        subtitleField.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleField.textColor = .secondaryLabelColor
        subtitleField.maximumNumberOfLines = 2

        let stack = NSStackView(views: [titleField, subtitleField])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        return stack
    }

    private func makeSettingRow(_ title: String, _ subtitle: String, _ control: NSView) -> NSView {
        let titleField = NSTextField(labelWithString: title)
        titleField.font = .systemFont(ofSize: 13, weight: .semibold)
        titleField.textColor = .labelColor

        let subtitleField = NSTextField(labelWithString: subtitle)
        subtitleField.font = .systemFont(ofSize: 11, weight: .regular)
        subtitleField.textColor = .secondaryLabelColor
        subtitleField.maximumNumberOfLines = 2

        let labelStack = NSStackView(views: [titleField, subtitleField])
        labelStack.orientation = .vertical
        labelStack.alignment = .leading
        labelStack.spacing = 3

        if let field = control as? NSTextField {
            NSLayoutConstraint.activate([
                field.widthAnchor.constraint(equalToConstant: 74)
            ])
        } else {
            NSLayoutConstraint.activate([
                control.widthAnchor.constraint(greaterThanOrEqualToConstant: 150)
            ])
        }

        let row = NSStackView(views: [labelStack, NSView(), control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 14
        return row
    }

    private func makeCheckboxRow(_ checkbox: NSButton, title: String, subtitle: String) -> NSView {
        let titleField = NSTextField(labelWithString: title)
        titleField.font = .systemFont(ofSize: 13, weight: .semibold)
        titleField.textColor = .labelColor

        let subtitleField = NSTextField(labelWithString: subtitle)
        subtitleField.font = .systemFont(ofSize: 11, weight: .regular)
        subtitleField.textColor = .secondaryLabelColor
        subtitleField.maximumNumberOfLines = 2

        let labels = NSStackView(views: [titleField, subtitleField])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2

        let row = NSStackView(views: [checkbox, labels])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 8
        return row
    }

    private func makeProminentButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.contentTintColor = .white
        button.wantsLayer = true
        button.layer?.cornerRadius = 12
        return button
    }

    private func makeBadge(title: String, tint: NSColor) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = tint.blended(withFraction: 0.1, of: .labelColor) ?? tint

        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 999
        container.layer?.backgroundColor = tint.withAlphaComponent(0.12).cgColor

        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6)
        ])
        return container
    }

    private func wrapInCard(content: NSView, inset: CGFloat, accent: Bool = false) -> NSView {
        let container = NSVisualEffectView()
        container.material = .windowBackground
        container.blendingMode = .withinWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.white.cgColor
        container.layer?.cornerRadius = 22
        container.layer?.borderWidth = 1
        container.layer?.borderColor = (accent
            ? NSColor.systemBlue.withAlphaComponent(0.18)
            : NSColor.separatorColor.withAlphaComponent(0.28)).cgColor
        container.layer?.shadowOpacity = 0.08
        container.layer?.shadowRadius = 18
        container.layer?.shadowOffset = CGSize(width: 0, height: -2)
        container.layer?.shadowColor = NSColor.black.cgColor

        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset),
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: inset),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -inset)
        ])
        return container
    }

    private func loadPreferences() {
        let preferences = store.preferences
        themePopup.selectItem(at: ZnakThemePreset.allCases.firstIndex(of: preferences.themePreset) ?? 0)
        builtinDictionaryCheckbox.state = preferences.enableBuiltinDictionary ? .on : .off
        customDictionaryCheckbox.state = preferences.enableCustomDictionary ? .on : .off
        predictionCheckbox.state = preferences.enablePrediction ? .on : .off
        latinPredictionCheckbox.state = preferences.enableLatinPrediction ? .on : .off
        learningCheckbox.state = preferences.enableLearning ? .on : .off
        correctionCheckbox.state = preferences.enableAutoCorrection ? .on : .off
        capsLockPopup.selectItem(at: InputPreferences.CapsLockBehavior.allCases.firstIndex(of: preferences.capsLockBehavior) ?? 0)
        preeditStylePopup.selectItem(at: InputPreferences.PreeditStyle.allCases.firstIndex(of: preferences.preeditStyle) ?? 0)
        rankingPopup.selectItem(at: InputPreferences.CandidateRankingPreference.allCases.firstIndex(of: preferences.candidateRankingPreference) ?? 0)
        candidateLayoutPopup.selectItem(at: InputPreferences.CandidateLayout.allCases.firstIndex(of: preferences.candidateLayout) ?? 0)
        perAppModeCheckbox.state = preferences.rememberModePerApp ? .on : .off
        temporaryEnglishCheckbox.state = preferences.enableTemporaryEnglishMode ? .on : .off
        persistModeCheckbox.state = preferences.persistInputModeState ? .on : .off
        shiftToastCheckbox.state = preferences.showShiftModeToast ? .on : .off
        candidateDetailsCheckbox.state = preferences.showCandidateDetails ? .on : .off
        candidateDebugCheckbox.state = preferences.showCandidateDebugInfo ? .on : .off
        candidateAnimationsCheckbox.state = preferences.enableCandidateAnimations ? .on : .off
        candidateCountField.stringValue = "\(preferences.maxCandidateCount)"
        candidateFontSizeField.stringValue = "\(preferences.candidateFontSize)"
        customDictionaryView.string = preferences.customDictionaryText
        learnedPreviewView.string = store.learnedDictionaryPreview()
    }

    @objc
    private func savePreferences() {
        let theme = ZnakThemePreset.allCases[safe: themePopup.indexOfSelectedItem] ?? .sogou
        let capsLockBehavior = InputPreferences.CapsLockBehavior.allCases[safe: capsLockPopup.indexOfSelectedItem] ?? .passthrough
        let preeditStyle = InputPreferences.PreeditStyle.allCases[safe: preeditStylePopup.indexOfSelectedItem] ?? .underline
        let ranking = InputPreferences.CandidateRankingPreference.allCases[safe: rankingPopup.indexOfSelectedItem] ?? .commonWords
        let candidateLayout = InputPreferences.CandidateLayout.allCases[safe: candidateLayoutPopup.indexOfSelectedItem] ?? .horizontal
        let count = Int(candidateCountField.stringValue) ?? InputPreferences.default.maxCandidateCount
        let fontSize = Int(candidateFontSizeField.stringValue) ?? InputPreferences.default.candidateFontSize
        let preferences = InputPreferences(
            themePreset: theme,
            enableBuiltinDictionary: builtinDictionaryCheckbox.state == .on,
            enableCustomDictionary: customDictionaryCheckbox.state == .on,
            enablePrediction: predictionCheckbox.state == .on,
            enableLatinPrediction: latinPredictionCheckbox.state == .on,
            enableLearning: learningCheckbox.state == .on,
            enableAutoCorrection: correctionCheckbox.state == .on,
            maxCandidateCount: count,
            candidateRankingPreference: ranking,
            candidateLayout: candidateLayout,
            candidateFontSize: fontSize,
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
    @objc
    private func importCustomDictionary() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .utf8PlainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK,
                  let url = panel.url,
                  let text = try? String(contentsOf: url, encoding: .utf8) else { return }
            self?.customDictionaryView.string = text
            self?.savePreferences()
        }
    }

    @objc
    private func exportCustomDictionary() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "ZnakCustomDictionary.txt"
        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK,
                  let url = panel.url,
                  let text = self?.customDictionaryView.string else { return }
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                NSLog("[Znak] Failed to export custom dictionary: \(error.localizedDescription)")
            }
        }
    }

    @objc
    private func openReleasesPage() {
        var request = URLRequest(url: Self.latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Znak Update Checker", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            if let error {
                DispatchQueue.main.async {
                    self?.showUpdateMessage(
                        title: "检查更新失败 / Update Check Failed / Ошибка проверки",
                        message: "无法读取 GitHub 最新版本：\(error.localizedDescription)\nUnable to read the latest GitHub release.\nНе удалось получить последнюю версию с GitHub."
                    )
                }
                return
            }

            guard let data,
                  let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else {
                DispatchQueue.main.async {
                    self?.showUpdateMessage(
                        title: "检查更新失败 / Update Check Failed / Ошибка проверки",
                        message: "GitHub 返回的数据无法解析。\nThe GitHub response could not be parsed.\nОтвет GitHub не удалось обработать."
                    )
                }
                return
            }

            let currentVersion = Self.currentAppVersion
            let latestVersion = Self.normalizedVersion(release.tagName)
            guard Self.compareVersions(latestVersion, currentVersion) == .orderedDescending else {
                DispatchQueue.main.async {
                    self?.showUpdateMessage(
                        title: "已是最新版本 / Up to Date / Уже последняя версия",
                        message: "当前版本：v\(currentVersion)\n最新版本：v\(latestVersion)\n\nYou are already using the latest version.\nВы уже используете последнюю версию."
                    )
                }
                return
            }

            if let appZip = release.assets.first(where: { $0.name.lowercased().hasSuffix(".app.zip") }) {
                self?.downloadAndInstallUpdateApp(from: appZip.browserDownloadURL, assetName: appZip.name, latestVersion: latestVersion)
                return
            }

            if let pkg = release.assets.first(where: { $0.name.lowercased().hasSuffix(".pkg") }) {
                self?.downloadUpdatePackage(from: pkg.browserDownloadURL, assetName: pkg.name, latestVersion: latestVersion)
                return
            }

            DispatchQueue.main.async {
                self?.showUpdateMessage(
                    title: "发现新版本 / Update Available / Доступно обновление",
                    message: "v\(latestVersion) 已发布，但没有找到 macOS app 或 pkg 安装包。\nA new version is available, but no macOS app or pkg asset was found.\nНовая версия доступна, но app/pkg установщик не найден."
                )
            }
        }.resume()
    }

    private nonisolated func downloadAndInstallUpdateApp(from url: URL, assetName: String, latestVersion: String) {
        URLSession.shared.downloadTask(with: url) { [weak self] temporaryURL, _, error in
            if let error {
                DispatchQueue.main.async {
                    self?.showUpdateMessage(
                        title: "下载失败 / Download Failed / Ошибка загрузки",
                        message: "无法下载 v\(latestVersion)：\(error.localizedDescription)\nUnable to download the update.\nНе удалось загрузить обновление."
                    )
                }
                return
            }

            guard let temporaryURL else {
                DispatchQueue.main.async {
                    self?.showUpdateMessage(
                        title: "下载失败 / Download Failed / Ошибка загрузки",
                        message: "下载文件不可用。\nThe downloaded file is unavailable.\nЗагруженный файл недоступен."
                    )
                }
                return
            }

            let fileManager = FileManager.default
            let workDirectory = fileManager.temporaryDirectory
                .appendingPathComponent("ZnakUpdate-\(UUID().uuidString)", isDirectory: true)

            do {
                try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)
                defer { try? fileManager.removeItem(at: workDirectory) }

                let unzip = Process()
                unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                unzip.arguments = ["-x", "-k", temporaryURL.path, workDirectory.path]
                try unzip.run()
                unzip.waitUntilExit()

                guard unzip.terminationStatus == 0 else {
                    throw NSError(domain: "ZnakUpdate", code: Int(unzip.terminationStatus), userInfo: [
                        NSLocalizedDescriptionKey: "ditto failed to extract \(assetName)"
                    ])
                }

                guard let extractedApp = Self.findExtractedZnakApp(in: workDirectory) else {
                    throw NSError(domain: "ZnakUpdate", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Znak.app was not found in \(assetName)"
                    ])
                }

                guard let userLibrary = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
                    throw NSError(domain: "ZnakUpdate", code: 2, userInfo: [
                        NSLocalizedDescriptionKey: "User Library directory is unavailable"
                    ])
                }

                let inputMethodsDirectory = userLibrary.appendingPathComponent("Input Methods", isDirectory: true)
                let destination = inputMethodsDirectory.appendingPathComponent("Znak.app", isDirectory: true)
                let stagingDestination = inputMethodsDirectory
                    .appendingPathComponent("Znak.app.update-\(UUID().uuidString)", isDirectory: true)
                try fileManager.createDirectory(at: inputMethodsDirectory, withIntermediateDirectories: true)
                try fileManager.copyItem(at: extractedApp, to: stagingDestination)
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.moveItem(at: stagingDestination, to: destination)

                DispatchQueue.main.async {
                    self?.showUpdateMessage(
                        title: "更新已安装 / Update Installed / Обновление установлено",
                        message: "已安装 v\(latestVersion) 到当前用户输入法目录。Znak 将重新打开。\nInstalled v\(latestVersion) into the current user's Input Methods folder. Znak will reopen.\nВерсия v\(latestVersion) установлена в папку метода ввода текущего пользователя. Znak будет перезапущен."
                    )
                    NSWorkspace.shared.open(destination)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        NSApp.terminate(nil)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.showUpdateMessage(
                        title: "安装失败 / Install Failed / Ошибка установки",
                        message: "无法安装 v\(latestVersion)：\(error.localizedDescription)\nUnable to install the update.\nНе удалось установить обновление."
                    )
                }
            }
        }.resume()
    }

    private nonisolated func downloadUpdatePackage(from url: URL, assetName: String, latestVersion: String) {
        URLSession.shared.downloadTask(with: url) { [weak self] temporaryURL, _, error in
            if let error {
                DispatchQueue.main.async {
                    self?.showUpdateMessage(
                        title: "下载失败 / Download Failed / Ошибка загрузки",
                        message: "无法下载 v\(latestVersion)：\(error.localizedDescription)\nUnable to download the update.\nНе удалось загрузить обновление."
                    )
                }
                return
            }

            guard let temporaryURL,
                  let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
                DispatchQueue.main.async {
                    self?.showUpdateMessage(
                        title: "下载失败 / Download Failed / Ошибка загрузки",
                        message: "无法访问下载目录。\nThe Downloads folder is unavailable.\nПапка загрузок недоступна."
                    )
                }
                return
            }

            let destination = downloads.appendingPathComponent(assetName)
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: temporaryURL, to: destination)
                DispatchQueue.main.async {
                    self?.showUpdateMessage(
                        title: "已下载新版本 / Update Downloaded / Обновление загружено",
                        message: "已下载 v\(latestVersion)：\n\(destination.path)\n\nThe installer will open now.\nУстановщик сейчас откроется."
                    )
                    NSWorkspace.shared.open(destination)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.showUpdateMessage(
                        title: "下载失败 / Download Failed / Ошибка загрузки",
                        message: "无法保存安装包：\(error.localizedDescription)\nUnable to save the installer.\nНе удалось сохранить установщик."
                    )
                }
            }
        }.resume()
    }

    private func showUpdateMessage(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    private nonisolated static func findExtractedZnakApp(in directory: URL) -> URL? {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: directory.appendingPathComponent("Znak.app").path) {
            return directory.appendingPathComponent("Znak.app")
        }

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let url as URL in enumerator where url.lastPathComponent == "Znak.app" {
            return url
        }
        return nil
    }

    private nonisolated static var currentAppVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return normalizedVersion(version ?? "0")
    }

    private nonisolated static func normalizedVersion(_ version: String) -> String {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    private nonisolated static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsParts = lhs.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        let rhsParts = rhs.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        let count = max(lhsParts.count, rhsParts.count)
        for index in 0..<count {
            let left = index < lhsParts.count ? lhsParts[index] : 0
            let right = index < rhsParts.count ? rhsParts[index] : 0
            if left < right { return .orderedAscending }
            if left > right { return .orderedDescending }
        }
        return .orderedSame
    }

}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
