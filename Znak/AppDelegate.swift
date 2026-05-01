import AppKit
import InputMethodKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let server: IMKServer
    private lazy var preferencesWindowController = PreferencesWindowController()
    private var statusItem: NSStatusItem?
    private var modeObserver: NSObjectProtocol?

    init(server: IMKServer) {
        self.server = server
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = server
        setupStatusItem()
        modeObserver = NotificationCenter.default.addObserver(
            forName: .znakInputModeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshStatusItem()
        }
        refreshStatusItem()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = nil
        item.button?.title = "RU"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Znak", action: #selector(quitApp), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    private func refreshStatusItem() {
        let mode = PreferencesStore.shared.loadInputModeState().globalMode == "english" ? "EN" : "RU"
        statusItem?.button?.title = mode
        statusItem?.button?.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
    }

    @objc
    private func openSettings() {
        preferencesWindowController.showWindowAndActivate()
    }

    @objc
    private func quitApp() {
        NSApp.terminate(nil)
    }
}
