import AppKit
import Foundation

enum ZnakThemePreset: String, CaseIterable, Codable {
    case sogou
    case classic

    var displayName: String {
        switch self {
        case .sogou: return "Sogou"
        case .classic: return "Classic"
        }
    }
}

struct InputPreferences: Codable, Equatable {
    enum PreeditStyle: String, CaseIterable, Codable {
        case underline
        case filled
        case minimal

        var displayName: String {
            switch self {
            case .underline: return "下划线"
            case .filled: return "高亮底色"
            case .minimal: return "极简"
            }
        }
    }

    enum CapsLockBehavior: String, CaseIterable, Codable {
        case passthrough
        case uppercaseRussian
        case toggleEnglish

        var displayName: String {
            switch self {
            case .passthrough: return "直接透传"
            case .uppercaseRussian: return "俄语大写"
            case .toggleEnglish: return "切到英文"
            }
        }
    }

    var themePreset: ZnakThemePreset
    var enableBuiltinDictionary: Bool
    var enableCustomDictionary: Bool
    var enablePrediction: Bool
    var enableLearning: Bool
    var enableAutoCorrection: Bool
    var maxCandidateCount: Int
    var customDictionaryText: String
    var capsLockBehavior: CapsLockBehavior
    var rememberModePerApp: Bool
    var enableTemporaryEnglishMode: Bool
    var persistInputModeState: Bool
    var showShiftModeToast: Bool
    var preeditStyle: PreeditStyle
    var showCandidateDetails: Bool
    var showCandidateDebugInfo: Bool
    var enableCandidateAnimations: Bool

    static let `default` = InputPreferences(
        themePreset: .sogou,
        enableBuiltinDictionary: true,
        enableCustomDictionary: true,
        enablePrediction: true,
        enableLearning: true,
        enableAutoCorrection: true,
        maxCandidateCount: 24,
        customDictionaryText: """
        # 每行一个词，可选频率：词 频率
        """,
        capsLockBehavior: .passthrough,
        rememberModePerApp: true,
        enableTemporaryEnglishMode: true,
        persistInputModeState: true,
        showShiftModeToast: true,
        preeditStyle: .underline,
        showCandidateDetails: true,
        showCandidateDebugInfo: false,
        enableCandidateAnimations: true
    )
}

extension Notification.Name {
    static let znakPreferencesDidChange = Notification.Name("ZnakPreferencesDidChange")
    static let znakInputModeDidChange = Notification.Name("ZnakInputModeDidChange")
}

final class PreferencesStore: @unchecked Sendable {
    static let shared = PreferencesStore()

    private enum DefaultsKey {
        static let blob = "ZnakInputPreferences"
        static let inputModeBlob = "ZnakInputModeState"
    }

    struct InputModeState: Codable, Equatable {
        var globalMode: String
        var appModes: [String: String]
    }

    private let defaults: UserDefaults
    private let fileManager: FileManager

    init(defaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        self.defaults = defaults
        self.fileManager = fileManager
    }

    var preferences: InputPreferences {
        get {
            guard let data = defaults.data(forKey: DefaultsKey.blob),
                  let decoded = try? JSONDecoder().decode(InputPreferences.self, from: data) else {
                return .default
            }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: DefaultsKey.blob)
            defaults.set(newValue.themePreset.rawValue, forKey: "CandidateThemePreset")
            NotificationCenter.default.post(name: .znakPreferencesDidChange, object: nil)
        }
    }

    func resetLearningData() {
        let urls = [
            appSupportDirectory()?.appendingPathComponent("user_dictionary.json"),
            appSupportDirectory()?.appendingPathComponent("user_dictionary.backup.json")
        ]

        for url in urls.compactMap({ $0 }) {
            try? fileManager.removeItem(at: url)
        }
        NotificationCenter.default.post(name: .znakPreferencesDidChange, object: nil)
    }

    func learnedDictionaryPreview() -> String {
        guard let url = appSupportDirectory()?.appendingPathComponent("user_dictionary.json"),
              let data = try? Data(contentsOf: url),
              let string = String(data: data, encoding: .utf8) else {
            return "{\n  \"wordScores\": {},\n  \"inputWordScores\": {}\n}"
        }
        return string
    }

    func loadInputModeState() -> InputModeState {
        guard let data = defaults.data(forKey: DefaultsKey.inputModeBlob),
              let decoded = try? JSONDecoder().decode(InputModeState.self, from: data) else {
            return InputModeState(globalMode: "russian", appModes: [:])
        }
        return decoded
    }

    func saveInputModeState(_ state: InputModeState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: DefaultsKey.inputModeBlob)
        NotificationCenter.default.post(name: .znakInputModeDidChange, object: nil)
    }

    private func appSupportDirectory() -> URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = appSupport.appendingPathComponent("Znak", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

extension InputPreferences {
    var sanitized: InputPreferences {
        var copy = self
        copy.maxCandidateCount = min(max(copy.maxCandidateCount, 8), 64)
        return copy
    }
}
