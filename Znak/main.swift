import AppKit
import InputMethodKit

let connectionName = Bundle.main.object(forInfoDictionaryKey: "InputMethodConnectionName") as? String ?? "Znak_Connection"
guard let server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier) else {
    fatalError("Unable to start Znak input method server.")
}

let app = NSApplication.shared
let delegate = AppDelegate(server: server)

app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
