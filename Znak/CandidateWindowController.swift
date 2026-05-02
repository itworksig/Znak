@preconcurrency import AppKit
import QuartzCore

private enum CandidateThemeDefaultsKey {
    static let preset = "CandidateThemePreset"
    static let panelCornerRadius = "CandidateThemePanelCornerRadius"
    static let accentColorHex = "CandidateThemeAccentColorHex"
    static let panelBackgroundHex = "CandidateThemePanelBackgroundHex"
    static let borderColorHex = "CandidateThemeBorderColorHex"
    static let shadowColorHex = "CandidateThemeShadowColorHex"
    static let primaryTextHex = "CandidateThemePrimaryTextHex"
    static let secondaryTextHex = "CandidateThemeSecondaryTextHex"
    static let compositionTextHex = "CandidateThemeCompositionTextHex"
    static let compositionUnderlineHex = "CandidateThemeCompositionUnderlineHex"
    static let separatorColorHex = "CandidateThemeSeparatorColorHex"
}

private struct CandidateTheme {
    let panelBackgroundColor: NSColor
    let borderColor: NSColor
    let separatorColor: NSColor
    let shadowColor: NSColor
    let accentColor: NSColor
    let primaryTextColor: NSColor
    let secondaryTextColor: NSColor
    let compositionTextColor: NSColor
    let compositionUnderlineColor: NSColor
    let highlightedTextColor: NSColor
    let highlightedSecondaryTextColor: NSColor
    let tagBackgroundColor: NSColor
    let tagTextColor: NSColor
    let debugTextColor: NSColor
    let toastBackgroundColor: NSColor
    let toastTextColor: NSColor
    let panelCornerRadius: CGFloat
    let panelShadowBlur: CGFloat
    let panelShadowYOffset: CGFloat
    let compositionUnderlineWidth: CGFloat

    static func current() -> CandidateTheme {
        let defaults = UserDefaults.standard
        let preset = defaults.string(forKey: CandidateThemeDefaultsKey.preset)?.lowercased() ?? "sogou"
        let base = preset == "classic" ? CandidateTheme.classic : CandidateTheme.sogou

        return CandidateTheme(
            panelBackgroundColor: defaults.color(forKey: CandidateThemeDefaultsKey.panelBackgroundHex) ?? base.panelBackgroundColor,
            borderColor: defaults.color(forKey: CandidateThemeDefaultsKey.borderColorHex) ?? base.borderColor,
            separatorColor: defaults.color(forKey: CandidateThemeDefaultsKey.separatorColorHex) ?? base.separatorColor,
            shadowColor: defaults.color(forKey: CandidateThemeDefaultsKey.shadowColorHex) ?? base.shadowColor,
            accentColor: defaults.color(forKey: CandidateThemeDefaultsKey.accentColorHex) ?? base.accentColor,
            primaryTextColor: defaults.color(forKey: CandidateThemeDefaultsKey.primaryTextHex) ?? base.primaryTextColor,
            secondaryTextColor: defaults.color(forKey: CandidateThemeDefaultsKey.secondaryTextHex) ?? base.secondaryTextColor,
            compositionTextColor: defaults.color(forKey: CandidateThemeDefaultsKey.compositionTextHex) ?? base.compositionTextColor,
            compositionUnderlineColor: defaults.color(forKey: CandidateThemeDefaultsKey.compositionUnderlineHex) ?? base.compositionUnderlineColor,
            highlightedTextColor: base.highlightedTextColor,
            highlightedSecondaryTextColor: base.highlightedSecondaryTextColor,
            tagBackgroundColor: base.tagBackgroundColor,
            tagTextColor: base.tagTextColor,
            debugTextColor: base.debugTextColor,
            toastBackgroundColor: base.toastBackgroundColor,
            toastTextColor: base.toastTextColor,
            panelCornerRadius: defaults.double(forKey: CandidateThemeDefaultsKey.panelCornerRadius).flatMapNonZero { CGFloat($0) } ?? base.panelCornerRadius,
            panelShadowBlur: base.panelShadowBlur,
            panelShadowYOffset: base.panelShadowYOffset,
            compositionUnderlineWidth: base.compositionUnderlineWidth
        )
    }

    static let sogou = CandidateTheme(
        panelBackgroundColor: .hex("#FFFFFF", alpha: 0.992),
        borderColor: .hex("#202124", alpha: 0.82),
        separatorColor: .hex("#D7DCE7"),
        shadowColor: .hex("#001847", alpha: 0.18),
        accentColor: .hex("#1677F2"),
        primaryTextColor: .hex("#181A20"),
        secondaryTextColor: .hex("#838B9A"),
        compositionTextColor: .hex("#20242D"),
        compositionUnderlineColor: .hex("#1677F2"),
        highlightedTextColor: .white,
        highlightedSecondaryTextColor: .white.withAlphaComponent(0.92),
        tagBackgroundColor: .hex("#EEF4FF"),
        tagTextColor: .hex("#2457A5"),
        debugTextColor: .hex("#556070"),
        toastBackgroundColor: .hex("#101218", alpha: 0.92),
        toastTextColor: .white,
        panelCornerRadius: 18,
        panelShadowBlur: 28,
        panelShadowYOffset: -6,
        compositionUnderlineWidth: 2
    )

    static let classic = CandidateTheme(
        panelBackgroundColor: .windowBackgroundColor.withAlphaComponent(0.975),
        borderColor: .separatorColor.withAlphaComponent(0.92),
        separatorColor: .separatorColor.withAlphaComponent(0.78),
        shadowColor: .black.withAlphaComponent(0.15),
        accentColor: .controlAccentColor,
        primaryTextColor: .labelColor,
        secondaryTextColor: .tertiaryLabelColor,
        compositionTextColor: .labelColor,
        compositionUnderlineColor: .controlAccentColor,
        highlightedTextColor: .white,
        highlightedSecondaryTextColor: .white.withAlphaComponent(0.86),
        tagBackgroundColor: .controlAccentColor.withAlphaComponent(0.14),
        tagTextColor: .controlAccentColor,
        debugTextColor: .secondaryLabelColor,
        toastBackgroundColor: .labelColor.withAlphaComponent(0.92),
        toastTextColor: .white,
        panelCornerRadius: 11,
        panelShadowBlur: 18,
        panelShadowYOffset: -4,
        compositionUnderlineWidth: 1.5
    )
}

private struct CandidatePanelConfig {
    let showDetails: Bool
    let showDebugInfo: Bool
    let enableAnimations: Bool
    let layout: InputPreferences.CandidateLayout
    let fontSize: CGFloat

    static func current() -> CandidatePanelConfig {
        let preferences = PreferencesStore.shared.preferences.sanitized
        return CandidatePanelConfig(
            showDetails: preferences.showCandidateDetails,
            showDebugInfo: preferences.showCandidateDebugInfo,
            enableAnimations: preferences.enableCandidateAnimations,
            layout: preferences.candidateLayout,
            fontSize: CGFloat(preferences.candidateFontSize)
        )
    }
}

final class CandidateWindowController {
    var onCandidateSelected: ((Int) -> Void)?

    private let panel: NSPanel
    private let rootView: CandidatePanelRootView

    init() {
        Self.ensureMainThread()
        rootView = CandidatePanelRootView(frame: .zero)
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.backgroundColor = .clear
        panel.contentView = rootView
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
        panel.contentView?.wantsLayer = true
        rootView.onCandidateSelected = { [weak self] index in
            self?.onCandidateSelected?(index)
        }
    }

    func show(composition: String, candidates: [InputEngine.Candidate], highlightedIndex: Int, pageLabel: String, cursorRect: NSRect?) {
        Self.ensureMainThread()
        guard !composition.isEmpty || !candidates.isEmpty else {
            hide()
            return
        }

        let theme = CandidateTheme.current()
        let config = CandidatePanelConfig.current()
        apply(theme: theme)
        rootView.theme = theme
        rootView.config = config
        rootView.pageLabel = pageLabel
        rootView.update(composition: composition, candidates: candidates, highlightedIndex: highlightedIndex)

        let size = rootView.fittingSize
        let origin = panelOrigin(for: size, cursorRect: cursorRect)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
    }

    func setInputModeLabel(_ label: String) {
        Self.ensureMainThread()
        rootView.inputModeLabel = label
    }

    func showToast(_ text: String) {
        Self.ensureMainThread()
        rootView.showToast(text)
    }

    func hide() {
        Self.ensureMainThread()
        panel.orderOut(nil)
    }

    func reloadTheme() {
        Self.ensureMainThread()
        let theme = CandidateTheme.current()
        apply(theme: theme)
        rootView.theme = theme
        rootView.config = .current()
        rootView.needsLayout = true
        rootView.needsDisplay = true
    }

    private func panelOrigin(for size: NSSize, cursorRect: NSRect?) -> NSPoint {
        let gap: CGFloat = 6
        let screen = screen(for: cursorRect) ?? screenContainingMouse() ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let anchor = validAnchorRect(from: cursorRect) ?? fallbackAnchor(in: visibleFrame)
        let margin: CGFloat = 4
        let maxX = max(visibleFrame.minX + margin, visibleFrame.maxX - size.width - margin)
        let x = min(max(anchor.minX, visibleFrame.minX + margin), maxX)
        let belowY = anchor.minY - size.height - gap
        let aboveY = anchor.maxY + gap
        let preferredY = belowY >= visibleFrame.minY + margin ? belowY : aboveY
        let maxY = max(visibleFrame.minY + margin, visibleFrame.maxY - size.height - margin)
        let y = min(max(preferredY, visibleFrame.minY + margin), maxY)
        return NSPoint(x: x, y: y)
    }

    private func validAnchorRect(from rect: NSRect?) -> NSRect? {
        guard let rect,
              !rect.isEmpty,
              rect.origin.x.isFinite,
              rect.origin.y.isFinite,
              rect.width.isFinite,
              rect.height.isFinite,
              rect.origin != .zero else {
            return nil
        }
        return rect
    }

    private func screen(for cursorRect: NSRect?) -> NSScreen? {
        guard let anchor = validAnchorRect(from: cursorRect) else { return nil }
        return NSScreen.screens.first { $0.visibleFrame.intersects(anchor) || $0.frame.contains(anchor.origin) }
            ?? NSScreen.screens.min { lhs, rhs in
                lhs.visibleFrame.distanceSquared(to: anchor.origin) < rhs.visibleFrame.distanceSquared(to: anchor.origin)
            }
    }

    private func screenContainingMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) }
    }

    private func fallbackAnchor(in visibleFrame: NSRect) -> NSRect {
        let mouse = NSEvent.mouseLocation
        if visibleFrame.contains(mouse) {
            return NSRect(x: mouse.x, y: mouse.y, width: 1, height: 20)
        }
        return NSRect(x: visibleFrame.minX + 24, y: visibleFrame.maxY - 120, width: 1, height: 20)
    }

    private func apply(theme: CandidateTheme) {
        panel.backgroundColor = .clear
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView?.layer?.cornerRadius = theme.panelCornerRadius
        panel.contentView?.layer?.shadowColor = theme.shadowColor.cgColor
        panel.contentView?.layer?.shadowOpacity = 1
        panel.contentView?.layer?.shadowRadius = theme.panelShadowBlur
        panel.contentView?.layer?.shadowOffset = CGSize(width: 0, height: theme.panelShadowYOffset)
        panel.contentView?.layer?.shadowPath = CGPath(
            roundedRect: panel.contentView?.bounds.insetBy(dx: 0.5, dy: 0.5) ?? .zero,
            cornerWidth: theme.panelCornerRadius,
            cornerHeight: theme.panelCornerRadius,
            transform: nil
        )
    }

    private static func ensureMainThread() {
        dispatchPrecondition(condition: .onQueue(.main))
    }
}

private struct CandidateLayoutItem {
    let index: Int
    let rect: NSRect
}

private final class CandidatePanelRootView: NSView {
    var theme: CandidateTheme = .current() {
        didSet { applyTheme() }
    }
    var config: CandidatePanelConfig = .current() {
        didSet {
            headerView.config = config
            stripView.config = config
            invalidateIntrinsicContentSize()
            needsLayout = true
        }
    }
    var inputModeLabel: String = "RU" {
        didSet { headerView.inputModeLabel = inputModeLabel }
    }
    var pageLabel: String = "" {
        didSet { headerView.pageLabel = pageLabel }
    }
    var onCandidateSelected: ((Int) -> Void)? {
        didSet { stripView.onCandidateSelected = onCandidateSelected }
    }

    private let backgroundView = CandidateBackgroundView(frame: .zero)
    private let headerView = CandidateHeaderView(frame: .zero)
    private let stripView = CandidateStripView(frame: .zero)
    private let toastView = CandidateToastView(frame: .zero)

    private let fixedPanelWidth: CGFloat = 760
    private let headerHeight: CGFloat = 40
    private let baseStripHeight: CGFloat = 52
    private let detailedStripHeight: CGFloat = 112
    private let debugHeight: CGFloat = 20

    override var isFlipped: Bool { true }

    override var fittingSize: NSSize {
        if config.layout == .vertical {
            let itemHeight = config.showDetails ? detailedStripHeight : baseStripHeight
            let debugExtra = config.showDebugInfo ? debugHeight : 0
            return NSSize(width: 430, height: headerHeight + itemHeight * 5 + debugExtra + 12)
        }
        let stripHeight = config.showDetails ? detailedStripHeight : baseStripHeight
        let debugExtra = config.showDebugInfo ? debugHeight : 0
        return NSSize(width: fixedPanelWidth, height: headerHeight + stripHeight + debugExtra)
    }

    override var intrinsicContentSize: NSSize { fittingSize }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        [backgroundView, headerView, stripView, toastView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        toastView.isHidden = true
        headerView.inputModeLabel = inputModeLabel
        headerView.pageLabel = pageLabel
        headerView.onOpenSettings = {
            NotificationCenter.default.post(name: .znakOpenSettingsRequested, object: nil)
        }
        headerView.config = config
        stripView.config = config
        applyTheme()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        backgroundView.frame = bounds
        let stripHeight = config.layout == .vertical
            ? max(0, bounds.height - headerHeight)
            : (config.showDetails ? detailedStripHeight : baseStripHeight) + (config.showDebugInfo ? debugHeight : 0)
        headerView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: headerHeight)
        stripView.frame = NSRect(x: 0, y: headerHeight, width: bounds.width, height: stripHeight)
        let toastWidth = min(220, bounds.width - 32)
        toastView.frame = NSRect(x: bounds.width - toastWidth - 16, y: 6, width: toastWidth, height: 28)
        layer?.cornerRadius = theme.panelCornerRadius
    }

    func update(composition: String, candidates: [InputEngine.Candidate], highlightedIndex: Int) {
        headerView.composition = composition
        stripView.update(candidates: candidates, highlightedIndex: highlightedIndex)
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    func showToast(_ text: String) {
        toastView.theme = theme
        toastView.setText(text)
        toastView.isHidden = false
        if !config.enableAnimations {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                self.toastView.isHidden = true
            }
            return
        }
        toastView.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            toastView.animator().alphaValue = 1
        } completionHandler: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.18
                    self.toastView.animator().alphaValue = 0
                } completionHandler: {
                    self.toastView.isHidden = true
                }
            }
        }
    }

    private func applyTheme() {
        backgroundView.theme = theme
        headerView.theme = theme
        stripView.theme = theme
        toastView.theme = theme
        needsDisplay = true
        needsLayout = true
    }
}

private final class CandidateBackgroundView: NSView {
    var theme: CandidateTheme = .current() { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            xRadius: theme.panelCornerRadius,
            yRadius: theme.panelCornerRadius
        )
        theme.panelBackgroundColor.setFill()
        path.fill()
        theme.borderColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

private final class CandidateHeaderView: NSView {
    var theme: CandidateTheme = .current() { didSet { needsDisplay = true } }
    var config: CandidatePanelConfig = .current() { didSet { needsDisplay = true } }
    var composition: String = "" { didSet { needsDisplay = true } }
    var inputModeLabel: String = "RU" { didSet { needsDisplay = true } }
    var pageLabel: String = "" { didSet { needsDisplay = true } }
    var onOpenSettings: (() -> Void)?

    private let hPad: CGFloat = 18
    private let modeBadgeWidth: CGFloat = 42
    private let pageBadgeWidth: CGFloat = 54
    private let settingsBadgeWidth: CGFloat = 34
    private let compositionFont = NSFont.systemFont(ofSize: 19, weight: .semibold)
    private let modeFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
    private let settingsFont = NSFont.systemFont(ofSize: 15, weight: .semibold)

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: compositionFont,
            .foregroundColor: theme.compositionTextColor
        ]
        let size = composition.size(withAttributes: attrs)
        let x = hPad
        let y = max(6, (bounds.height - size.height) / 2 - 2)
        composition.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)

        let trailingReservedWidth = modeBadgeWidth + settingsBadgeWidth + 8 + (pageLabel.isEmpty ? 0 : pageBadgeWidth + 8)
        let underlineWidth = min(max(size.width, 24), bounds.width - x * 2 - trailingReservedWidth)
        let underlineRect = NSRect(x: x, y: bounds.height - 9, width: underlineWidth, height: theme.compositionUnderlineWidth)
        theme.compositionUnderlineColor.setFill()
        NSBezierPath(roundedRect: underlineRect, xRadius: 1, yRadius: 1).fill()

        theme.separatorColor.setFill()
        NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1).fill()
        drawSettingsBadge()
        drawModeBadge()
        drawPageBadgeIfNeeded()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if settingsBadgeRect.contains(point) {
            onOpenSettings?()
            return
        }
        super.mouseDown(with: event)
    }

    private func drawModeBadge() {
        let badgeRect = NSRect(x: bounds.width - hPad - modeBadgeWidth, y: 8, width: modeBadgeWidth, height: 24)
        let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 12, yRadius: 12)
        theme.accentColor.withAlphaComponent(0.12).setFill()
        badgePath.fill()
        theme.accentColor.withAlphaComponent(0.28).setStroke()
        badgePath.lineWidth = 1
        badgePath.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: modeFont,
            .foregroundColor: theme.accentColor
        ]
        let size = inputModeLabel.size(withAttributes: attrs)
        inputModeLabel.draw(
            at: NSPoint(x: badgeRect.midX - size.width / 2, y: badgeRect.midY - size.height / 2 - 1),
            withAttributes: attrs
        )
    }

    private func drawSettingsBadge() {
        let badgeRect = settingsBadgeRect
        let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 12, yRadius: 12)
        theme.borderColor.withAlphaComponent(0.06).setFill()
        badgePath.fill()
        theme.borderColor.withAlphaComponent(0.16).setStroke()
        badgePath.lineWidth = 1
        badgePath.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: settingsFont,
            .foregroundColor: theme.secondaryTextColor
        ]
        let title = "⚙"
        let size = title.size(withAttributes: attrs)
        title.draw(
            at: NSPoint(x: badgeRect.midX - size.width / 2, y: badgeRect.midY - size.height / 2 - 1),
            withAttributes: attrs
        )
    }

    private func drawPageBadgeIfNeeded() {
        guard !pageLabel.isEmpty else { return }
        let badgeRect = NSRect(x: settingsBadgeRect.minX - 8 - pageBadgeWidth, y: 8, width: pageBadgeWidth, height: 24)
        let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 12, yRadius: 12)
        theme.borderColor.withAlphaComponent(0.08).setFill()
        badgePath.fill()
        theme.borderColor.withAlphaComponent(0.18).setStroke()
        badgePath.lineWidth = 1
        badgePath.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: modeFont,
            .foregroundColor: theme.secondaryTextColor
        ]
        let size = pageLabel.size(withAttributes: attrs)
        pageLabel.draw(
            at: NSPoint(x: badgeRect.midX - size.width / 2, y: badgeRect.midY - size.height / 2 - 1),
            withAttributes: attrs
        )
    }

    private var settingsBadgeRect: NSRect {
        NSRect(x: bounds.width - hPad - modeBadgeWidth - 8 - settingsBadgeWidth, y: 8, width: settingsBadgeWidth, height: 24)
    }
}

private final class CandidateStripView: NSView {
    var theme: CandidateTheme = .current() { didSet { needsDisplay = true } }
    var config: CandidatePanelConfig = .current() { didSet { invalidateLayout() } }
    var onCandidateSelected: ((Int) -> Void)?

    private let rowHorizontalInset: CGFloat = 22
    private let itemSpacing: CGFloat = 10
    private let edgeFadeWidth: CGFloat = 16
    private let itemHorizontalPadding: CGFloat = 18
    private let indexColumnWidth: CGFloat = 28
    private let baseHeight: CGFloat = 48
    private let detailedHeight: CGFloat = 100
    private let debugHeight: CGFloat = 18
    private var titleFont: NSFont { NSFont.systemFont(ofSize: config.fontSize, weight: .semibold) }
    private let indexFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    private let metaFont = NSFont.systemFont(ofSize: 11, weight: .medium)
    private let debugFont = NSFont.systemFont(ofSize: 10, weight: .medium)

    private var candidates: [InputEngine.Candidate] = []
    private var highlightedIndex = 0
    private var candidateLayouts: [CandidateLayoutItem] = []
    private var scrollOffset: CGFloat = 0

    override var isFlipped: Bool { true }

    func update(candidates: [InputEngine.Candidate], highlightedIndex: Int) {
        self.candidates = candidates
        self.highlightedIndex = min(max(0, highlightedIndex), max(candidates.count - 1, 0))
        if self.highlightedIndex == 0 {
            scrollOffset = 0
        }
        rebuildCandidateLayout()
        ensureHighlightedCandidateVisible(animated: config.enableAnimations)
        invalidateLayout()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !candidateLayouts.isEmpty else { return }

        let viewport = candidateViewportRect
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: viewport).addClip()

        for layout in candidateLayouts {
            let rect = layout.rect.offsetBy(dx: -scrollOffset, dy: 0)
            guard rect.maxX >= viewport.minX - itemSpacing,
                  rect.minX <= viewport.maxX + itemSpacing else { continue }
            drawCandidate(candidates[layout.index], actualIndex: layout.index, in: rect)
        }

        NSGraphicsContext.restoreGraphicsState()
        drawViewportFadesIfNeeded()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let index = candidateIndex(at: point) else {
            super.mouseDown(with: event)
            return
        }
        highlightedIndex = index
        ensureHighlightedCandidateVisible(animated: config.enableAnimations)
        needsDisplay = true
        onCandidateSelected?(index)
    }

    private func drawCandidate(_ candidate: InputEngine.Candidate, actualIndex: Int, in rect: NSRect) {
        let isHighlighted = actualIndex == highlightedIndex
        let cardRect = rect.insetBy(dx: 1, dy: 4)
        let path = NSBezierPath(roundedRect: cardRect, xRadius: 12, yRadius: 12)
        if isHighlighted {
            theme.accentColor.setFill()
            path.fill()
        } else {
            theme.borderColor.withAlphaComponent(0.05).setFill()
            path.fill()
            theme.borderColor.withAlphaComponent(0.12).setStroke()
            path.lineWidth = 1
            path.stroke()
        }

        let primaryColor = isHighlighted ? theme.highlightedTextColor : theme.primaryTextColor
        let secondaryColor = isHighlighted ? theme.highlightedSecondaryTextColor : theme.secondaryTextColor
        let debugColor = isHighlighted ? theme.highlightedSecondaryTextColor.withAlphaComponent(0.86) : theme.debugTextColor

        let indexAttrs: [NSAttributedString.Key: Any] = [.font: indexFont, .foregroundColor: secondaryColor]
        let highlightedIndexAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: primaryColor
        ]
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: primaryColor]
        let metaAttrs: [NSAttributedString.Key: Any] = [.font: metaFont, .foregroundColor: secondaryColor]
        let debugAttrs: [NSAttributedString.Key: Any] = [.font: debugFont, .foregroundColor: debugColor]

        let indexText = "\(actualIndex + 1)."
        let titleY = config.showDetails
            ? cardRect.minY + 6
            : cardRect.midY - candidate.text.size(withAttributes: titleAttrs).height / 2 - 1

        let indexY = config.showDetails
            ? cardRect.minY + 9
            : cardRect.midY - indexText.size(withAttributes: indexAttrs).height / 2
        let titleX: CGFloat
        if isHighlighted && !config.showDetails {
            let combined = NSMutableAttributedString(string: "\(indexText)  ", attributes: highlightedIndexAttrs)
            combined.append(NSAttributedString(string: candidate.text, attributes: titleAttrs))
            combined.draw(
                in: NSRect(
                    x: cardRect.minX + itemHorizontalPadding,
                    y: titleY,
                    width: max(0, cardRect.width - itemHorizontalPadding * 2),
                    height: candidate.text.size(withAttributes: titleAttrs).height + 4
                )
            )
            titleX = cardRect.minX + itemHorizontalPadding + indexColumnWidth + 10
        } else {
            let indexWidth = indexText.size(withAttributes: indexAttrs).width
            let indexX = cardRect.minX + itemHorizontalPadding + max(0, indexColumnWidth - indexWidth) / 2
            indexText.draw(at: NSPoint(x: indexX, y: indexY), withAttributes: indexAttrs)
            titleX = cardRect.minX + itemHorizontalPadding + indexColumnWidth + 10
        }
        let titleRect = NSRect(
            x: titleX,
            y: titleY,
            width: max(0, cardRect.maxX - titleX - itemHorizontalPadding),
            height: candidate.text.size(withAttributes: titleAttrs).height + 4
        )
        if !isHighlighted || config.showDetails {
            candidate.text.draw(in: titleRect, withAttributes: titleAttrs)
        }

        if config.showDetails {
            let metaY = cardRect.minY + 34
            let metaText = candidate.annotation
            metaText.draw(at: NSPoint(x: titleX, y: metaY), withAttributes: metaAttrs)
            drawTag(candidate.partOfSpeech, at: NSPoint(x: titleX, y: cardRect.minY + 56), highlighted: isHighlighted)

            let sourceText = candidate.source.label
            let sourceWidth = sourceText.size(withAttributes: metaAttrs).width
            sourceText.draw(at: NSPoint(x: cardRect.maxX - sourceWidth - itemHorizontalPadding, y: metaY), withAttributes: metaAttrs)
        }

        if config.showDebugInfo {
            let debugY = cardRect.maxY - 18
            let clipped = clippedDebugText(candidate.debugSummary, maxWidth: cardRect.width - itemHorizontalPadding * 2, attrs: debugAttrs)
            clipped.draw(at: NSPoint(x: cardRect.minX + itemHorizontalPadding, y: debugY), withAttributes: debugAttrs)
        }
    }

    private func drawTag(_ text: String, at origin: NSPoint, highlighted: Bool) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: metaFont,
            .foregroundColor: highlighted ? theme.highlightedSecondaryTextColor : theme.tagTextColor
        ]
        let textSize = text.size(withAttributes: attrs)
        let rect = NSRect(x: origin.x, y: origin.y, width: textSize.width + 14, height: 18)
        let path = NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9)
        (highlighted ? NSColor.white.withAlphaComponent(0.14) : theme.tagBackgroundColor).setFill()
        path.fill()
        text.draw(at: NSPoint(x: rect.minX + 7, y: rect.minY + 2), withAttributes: attrs)
    }

    private func clippedDebugText(_ text: String, maxWidth: CGFloat, attrs: [NSAttributedString.Key: Any]) -> String {
        guard text.size(withAttributes: attrs).width > maxWidth else { return text }
        var clipped = text
        while !clipped.isEmpty && (clipped + "…").size(withAttributes: attrs).width > maxWidth {
            clipped.removeLast()
        }
        return clipped + "…"
    }

    private func drawViewportFadesIfNeeded() {
        let viewport = candidateViewportRect

        if scrollOffset > 0,
           let gradient = NSGradient(starting: theme.panelBackgroundColor, ending: theme.panelBackgroundColor.withAlphaComponent(0)) {
            gradient.draw(in: NSRect(x: viewport.minX, y: viewport.minY, width: edgeFadeWidth, height: viewport.height), angle: 0)
        }

        if scrollOffset < maxScrollOffset,
           let gradient = NSGradient(starting: theme.panelBackgroundColor.withAlphaComponent(0), ending: theme.panelBackgroundColor) {
            gradient.draw(in: NSRect(x: viewport.maxX - edgeFadeWidth, y: viewport.minY, width: edgeFadeWidth, height: viewport.height), angle: 0)
        }
    }

    private func rebuildCandidateLayout() {
        candidateLayouts.removeAll(keepingCapacity: true)
        guard !candidates.isEmpty else {
            scrollOffset = 0
            return
        }

        if config.layout == .vertical {
            var y = candidateViewportRect.minY
            for (index, candidate) in candidates.enumerated() {
                let rect = NSRect(x: candidateViewportRect.minX, y: y, width: candidateViewportRect.width, height: candidateCardHeight)
                candidateLayouts.append(CandidateLayoutItem(index: index, rect: rect))
                y += candidateCardHeight + 4
            }
        } else {
            var x = candidateViewportRect.minX
            let rowY = 4 as CGFloat
            for (index, candidate) in candidates.enumerated() {
                let width = itemWidth(for: candidate)
                let rect = NSRect(x: x, y: rowY, width: width, height: candidateCardHeight)
                candidateLayouts.append(CandidateLayoutItem(index: index, rect: rect))
                x += width + itemSpacing
            }
        }
        scrollOffset = min(scrollOffset, maxScrollOffset)
    }

    private func itemWidth(for candidate: InputEngine.Candidate) -> CGFloat {
        let titleWidth = candidate.text.size(withAttributes: [.font: titleFont]).width
        if !config.showDetails && !config.showDebugInfo {
            let highlightedIndexWidth = "\(candidates.firstIndex(of: candidate).map { $0 + 1 } ?? 1).  "
                .size(withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .semibold)])
                .width
            let simpleWidth = max(titleWidth + indexColumnWidth + 10, highlightedIndexWidth + titleWidth)
            return min(240, max(136, ceil(simpleWidth + itemHorizontalPadding * 2 + 2)))
        }

        let annotationWidth = candidate.annotation.size(withAttributes: [.font: metaFont]).width
        let sourceWidth = candidate.source.label.size(withAttributes: [.font: metaFont]).width
        let debugWidth = config.showDebugInfo ? candidate.debugSummary.size(withAttributes: [.font: debugFont]).width : 0
        let contentWidth = max(indexColumnWidth + 10 + titleWidth, annotationWidth + sourceWidth + 30, debugWidth)
        let baseMinWidth: CGFloat = config.showDetails ? 220 : 170
        return min(360, max(baseMinWidth, ceil(contentWidth + itemHorizontalPadding * 2 + 30)))
    }

    private func ensureHighlightedCandidateVisible(animated: Bool) {
        guard candidateLayouts.indices.contains(highlightedIndex) else {
            scrollOffset = 0
            return
        }

        let viewport = candidateViewportRect
        let target = candidateLayouts[highlightedIndex].rect
        let padding = edgeFadeWidth + 8
        let viewportStart = scrollOffset + viewport.minX
        let viewportEnd = scrollOffset + viewport.maxX
        var nextOffset = scrollOffset

        if target.minX < viewportStart + padding {
            nextOffset = max(0, target.minX - viewport.minX - padding)
        } else if target.maxX > viewportEnd - padding {
            nextOffset = min(maxScrollOffset, target.maxX - viewport.maxX + padding)
        }

        guard nextOffset != scrollOffset else { return }
        scrollOffset = nextOffset
        needsDisplay = true
    }

    private func candidateIndex(at point: NSPoint) -> Int? {
        let contentPoint = config.layout == .vertical ? point : NSPoint(x: point.x + scrollOffset, y: point.y)
        return candidateLayouts.first(where: { $0.rect.contains(contentPoint) })?.index
    }

    private var candidateViewportRect: NSRect {
        NSRect(x: rowHorizontalInset, y: 4, width: bounds.width - rowHorizontalInset * 2, height: config.layout == .vertical ? max(0, bounds.height - 8) : candidateCardHeight)
    }

    private var candidateCardHeight: CGFloat {
        (config.showDetails ? detailedHeight : baseHeight) + (config.showDetails && config.showDebugInfo ? debugHeight : 0)
    }

    private var maxScrollOffset: CGFloat {
        guard config.layout == .horizontal, let last = candidateLayouts.last else { return 0 }
        return max(0, last.rect.maxX - candidateViewportRect.maxX)
    }

    private func invalidateLayout() {
        needsDisplay = true
        needsLayout = true
        invalidateIntrinsicContentSize()
    }
}

private final class CandidateToastView: NSView {
    var theme: CandidateTheme = .current() { didSet { needsDisplay = true } }
    private var text: String = ""
    private let font = NSFont.systemFont(ofSize: 12, weight: .semibold)

    override var isFlipped: Bool { true }

    func setText(_ text: String) {
        self.text = text
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !text.isEmpty else { return }
        let path = NSBezierPath(roundedRect: bounds, xRadius: 14, yRadius: 14)
        theme.toastBackgroundColor.setFill()
        path.fill()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: theme.toastTextColor
        ]
        let size = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2 - 1), withAttributes: attrs)
    }
}

private extension UserDefaults {
    func color(forKey key: String) -> NSColor? {
        guard let hex = string(forKey: key) else { return nil }
        return NSColor.hex(hex)
    }
}

private extension NSColor {
    static func hex(_ hex: String, alpha: CGFloat = 1) -> NSColor {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard sanitized.count == 6, let value = Int(sanitized, radix: 16) else {
            return .clear
        }
        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}

private extension NSRect {
    func distanceSquared(to point: NSPoint) -> CGFloat {
        let clampedX = min(max(point.x, minX), maxX)
        let clampedY = min(max(point.y, minY), maxY)
        let dx = point.x - clampedX
        let dy = point.y - clampedY
        return dx * dx + dy * dy
    }
}

private extension Double {
    func flatMapNonZero<T>(_ transform: (Double) -> T) -> T? {
        self == 0 ? nil : transform(self)
    }
}
