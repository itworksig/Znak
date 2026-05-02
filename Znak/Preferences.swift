import AppKit
import Foundation

enum ZnakThemePreset: String, CaseIterable, Codable {
    case sogou
    case classic

        var displayName: String {
            switch self {
            case .sogou: return "搜狗 / Согу / Sogou"
            case .classic: return "经典 / Классика / Classic"
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
            case .underline: return "下划线 / Подчёркивание / Underline"
            case .filled: return "高亮底色 / Подсветка / Filled"
            case .minimal: return "极简 / Минимальный / Minimal"
            }
        }
    }

    enum CandidateRankingPreference: String, CaseIterable, Codable {
        case commonWords
        case directMapping
        case phrases

        var displayName: String {
            switch self {
            case .commonWords: return "优先常用词 / Частотные слова / Common words"
            case .directMapping: return "优先键位直映 / Прямая раскладка / Direct mapping"
            case .phrases: return "优先短语 / Фразы / Phrases first"
            }
        }
    }

    enum CandidateLayout: String, CaseIterable, Codable {
        case horizontal
        case vertical

        var displayName: String {
            switch self {
            case .horizontal: return "横向 / Горизонтально / Horizontal"
            case .vertical: return "纵向 / Вертикально / Vertical"
            }
        }
    }

    enum CapsLockBehavior: String, CaseIterable, Codable {
        case passthrough
        case uppercaseRussian
        case toggleEnglish

        var displayName: String {
            switch self {
            case .passthrough: return "直接透传 / Прямой ввод / Passthrough"
            case .uppercaseRussian: return "俄语大写 / Русский верхний регистр / Uppercase Russian"
            case .toggleEnglish: return "切到英文 / Переключить на English / Toggle English"
            }
        }
    }

    var themePreset: ZnakThemePreset
    var enableBuiltinDictionary: Bool
    var enableCustomDictionary: Bool
    var enablePrediction: Bool
    var enableLatinPrediction: Bool
    var enableLearning: Bool
    var enableAutoCorrection: Bool
    var maxCandidateCount: Int
    var candidateRankingPreference: CandidateRankingPreference
    var candidateLayout: CandidateLayout
    var candidateFontSize: Int
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

    private enum CodingKeys: String, CodingKey {
        case themePreset
        case enableBuiltinDictionary
        case enableCustomDictionary
        case enablePrediction
        case enableLatinPrediction
        case enableLearning
        case enableAutoCorrection
        case maxCandidateCount
        case candidateRankingPreference
        case candidateLayout
        case candidateFontSize
        case customDictionaryText
        case capsLockBehavior
        case rememberModePerApp
        case enableTemporaryEnglishMode
        case persistInputModeState
        case showShiftModeToast
        case preeditStyle
        case showCandidateDetails
        case showCandidateDebugInfo
        case enableCandidateAnimations
    }

    init(
        themePreset: ZnakThemePreset,
        enableBuiltinDictionary: Bool,
        enableCustomDictionary: Bool,
        enablePrediction: Bool,
        enableLatinPrediction: Bool,
        enableLearning: Bool,
        enableAutoCorrection: Bool,
        maxCandidateCount: Int,
        candidateRankingPreference: CandidateRankingPreference,
        candidateLayout: CandidateLayout,
        candidateFontSize: Int,
        customDictionaryText: String,
        capsLockBehavior: CapsLockBehavior,
        rememberModePerApp: Bool,
        enableTemporaryEnglishMode: Bool,
        persistInputModeState: Bool,
        showShiftModeToast: Bool,
        preeditStyle: PreeditStyle,
        showCandidateDetails: Bool,
        showCandidateDebugInfo: Bool,
        enableCandidateAnimations: Bool
    ) {
        self.themePreset = themePreset
        self.enableBuiltinDictionary = enableBuiltinDictionary
        self.enableCustomDictionary = enableCustomDictionary
        self.enablePrediction = enablePrediction
        self.enableLatinPrediction = enableLatinPrediction
        self.enableLearning = enableLearning
        self.enableAutoCorrection = enableAutoCorrection
        self.maxCandidateCount = maxCandidateCount
        self.candidateRankingPreference = candidateRankingPreference
        self.candidateLayout = candidateLayout
        self.candidateFontSize = candidateFontSize
        self.customDictionaryText = customDictionaryText
        self.capsLockBehavior = capsLockBehavior
        self.rememberModePerApp = rememberModePerApp
        self.enableTemporaryEnglishMode = enableTemporaryEnglishMode
        self.persistInputModeState = persistInputModeState
        self.showShiftModeToast = showShiftModeToast
        self.preeditStyle = preeditStyle
        self.showCandidateDetails = showCandidateDetails
        self.showCandidateDebugInfo = showCandidateDebugInfo
        self.enableCandidateAnimations = enableCandidateAnimations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = InputPreferences.default
        themePreset = try container.decodeIfPresent(ZnakThemePreset.self, forKey: .themePreset) ?? fallback.themePreset
        enableBuiltinDictionary = try container.decodeIfPresent(Bool.self, forKey: .enableBuiltinDictionary) ?? fallback.enableBuiltinDictionary
        enableCustomDictionary = try container.decodeIfPresent(Bool.self, forKey: .enableCustomDictionary) ?? fallback.enableCustomDictionary
        enablePrediction = try container.decodeIfPresent(Bool.self, forKey: .enablePrediction) ?? fallback.enablePrediction
        enableLatinPrediction = try container.decodeIfPresent(Bool.self, forKey: .enableLatinPrediction) ?? fallback.enableLatinPrediction
        enableLearning = try container.decodeIfPresent(Bool.self, forKey: .enableLearning) ?? fallback.enableLearning
        enableAutoCorrection = try container.decodeIfPresent(Bool.self, forKey: .enableAutoCorrection) ?? fallback.enableAutoCorrection
        maxCandidateCount = try container.decodeIfPresent(Int.self, forKey: .maxCandidateCount) ?? fallback.maxCandidateCount
        candidateRankingPreference = try container.decodeIfPresent(CandidateRankingPreference.self, forKey: .candidateRankingPreference) ?? fallback.candidateRankingPreference
        candidateLayout = try container.decodeIfPresent(CandidateLayout.self, forKey: .candidateLayout) ?? fallback.candidateLayout
        candidateFontSize = try container.decodeIfPresent(Int.self, forKey: .candidateFontSize) ?? fallback.candidateFontSize
        customDictionaryText = try container.decodeIfPresent(String.self, forKey: .customDictionaryText) ?? fallback.customDictionaryText
        capsLockBehavior = try container.decodeIfPresent(CapsLockBehavior.self, forKey: .capsLockBehavior) ?? fallback.capsLockBehavior
        rememberModePerApp = try container.decodeIfPresent(Bool.self, forKey: .rememberModePerApp) ?? fallback.rememberModePerApp
        enableTemporaryEnglishMode = try container.decodeIfPresent(Bool.self, forKey: .enableTemporaryEnglishMode) ?? fallback.enableTemporaryEnglishMode
        persistInputModeState = try container.decodeIfPresent(Bool.self, forKey: .persistInputModeState) ?? fallback.persistInputModeState
        showShiftModeToast = try container.decodeIfPresent(Bool.self, forKey: .showShiftModeToast) ?? fallback.showShiftModeToast
        preeditStyle = try container.decodeIfPresent(PreeditStyle.self, forKey: .preeditStyle) ?? fallback.preeditStyle
        showCandidateDetails = try container.decodeIfPresent(Bool.self, forKey: .showCandidateDetails) ?? fallback.showCandidateDetails
        showCandidateDebugInfo = try container.decodeIfPresent(Bool.self, forKey: .showCandidateDebugInfo) ?? fallback.showCandidateDebugInfo
        enableCandidateAnimations = try container.decodeIfPresent(Bool.self, forKey: .enableCandidateAnimations) ?? fallback.enableCandidateAnimations
    }

    static let `default` = InputPreferences(
        themePreset: .sogou,
        enableBuiltinDictionary: true,
        enableCustomDictionary: true,
        enablePrediction: true,
        enableLatinPrediction: false,
        enableLearning: true,
        enableAutoCorrection: true,
        maxCandidateCount: 24,
        candidateRankingPreference: .commonWords,
        candidateLayout: .horizontal,
        candidateFontSize: 19,
        customDictionaryText: """
        # 每行一个词，可选频率：词 频率
        """,
        capsLockBehavior: .passthrough,
        rememberModePerApp: true,
        enableTemporaryEnglishMode: true,
        persistInputModeState: false,
        showShiftModeToast: true,
        preeditStyle: .underline,
        showCandidateDetails: false,
        showCandidateDebugInfo: false,
        enableCandidateAnimations: true
    )
}

extension Notification.Name {
    static let znakPreferencesDidChange = Notification.Name("ZnakPreferencesDidChange")
    static let znakInputModeDidChange = Notification.Name("ZnakInputModeDidChange")
    static let znakOpenSettingsRequested = Notification.Name("ZnakOpenSettingsRequested")
    static let znakLearningDataDidReset = Notification.Name("ZnakLearningDataDidReset")
    static let znakLearningDataDiagnosticDidChange = Notification.Name("ZnakLearningDataDiagnosticDidChange")
}

final class PreferencesStore: @unchecked Sendable {
    static let shared = PreferencesStore()

    private enum DefaultsKey {
        static let blob = "ZnakInputPreferences"
        static let inputModeBlob = "ZnakInputModeState"
        static let learningDiagnostic = "ZnakLearningDataDiagnostic"
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
        defaults.removeObject(forKey: DefaultsKey.learningDiagnostic)
        NotificationCenter.default.post(name: .znakLearningDataDidReset, object: nil)
        NotificationCenter.default.post(name: .znakPreferencesDidChange, object: nil)
    }

    func learnedDictionaryPreview() -> String {
        let body: String
        if let url = appSupportDirectory()?.appendingPathComponent("user_dictionary.json"),
           let data = try? Data(contentsOf: url),
           let string = String(data: data, encoding: .utf8) {
            body = string
        } else {
            body = "{\n  \"wordScores\": {},\n  \"inputWordScores\": {}\n}"
        }

        guard let diagnostic = defaults.string(forKey: DefaultsKey.learningDiagnostic),
              !diagnostic.isEmpty else {
            return body
        }
        return "\(body)\n\n/* Last learning data diagnostic:\n\(diagnostic)\n*/"
    }

    static func publishLearningDiagnostic(_ message: String?) {
        if let message, !message.isEmpty {
            UserDefaults.standard.set(message, forKey: DefaultsKey.learningDiagnostic)
        } else {
            UserDefaults.standard.removeObject(forKey: DefaultsKey.learningDiagnostic)
        }
        NotificationCenter.default.post(name: .znakLearningDataDiagnosticDidChange, object: nil)
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
        copy.candidateFontSize = min(max(copy.candidateFontSize, 14), 28)
        return copy
    }
}
