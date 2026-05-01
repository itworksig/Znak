import Foundation

struct InputEngine {
    struct Candidate: Equatable {
        enum Source: String, Equatable {
            case mapped
            case builtin
            case custom
            case learned
            case phrase
            case fuzzy

            var label: String {
                switch self {
                case .mapped: return "映射"
                case .builtin: return "系统"
                case .custom: return "自定义"
                case .learned: return "学习"
                case .phrase: return "短语"
                case .fuzzy: return "纠错"
                }
            }
        }

        let text: String
        let frequency: Int
        let annotation: String
        let partOfSpeech: String
        let source: Source
        let debugSummary: String

        func withDebugSummary(_ debugSummary: String) -> Candidate {
            Candidate(
                text: text,
                frequency: frequency,
                annotation: annotation,
                partOfSpeech: partOfSpeech,
                source: source,
                debugSummary: debugSummary
            )
        }

        func withSource(_ source: Source) -> Candidate {
            Candidate(
                text: text,
                frequency: frequency,
                annotation: annotation,
                partOfSpeech: partOfSpeech,
                source: source,
                debugSummary: debugSummary
            )
        }
    }

    struct PhraseCandidate {
        let anchor: String?
        let text: String
        let frequency: Int
        let normalizedText: String
        let transliteration: String
    }

    private struct DictionaryEntry {
        let candidate: Candidate
        let textLower: String
        let transliteration: String
    }

    private struct DictionaryIndex {
        let entries: [DictionaryEntry]
        let buckets: [String: [DictionaryEntry]]

        func entries(for key: String) -> [DictionaryEntry] {
            buckets[key] ?? entries
        }
    }

    private struct QueryContext {
        let pool: [DictionaryEntry]
        let fuzzyPool: [DictionaryEntry]
    }

    private struct QueryCacheEntry {
        let input: String
        let preferences: InputPreferences
        let customDictionaryFingerprint: Int
        let context: QueryContext
    }

    private struct MatchScore {
        let candidate: Candidate
        let score: Int
        let isMappedExact: Bool
    }

    private let builtinIndex: DictionaryIndex
    private let phraseIndex: [String: [PhraseCandidate]]
    private let globalPhrases: [PhraseCandidate]
    private var customIndex: DictionaryIndex
    private var preferences: InputPreferences
    private var customDictionaryFingerprint: Int
    private var userLexicon = UserLexiconStore()
    private var queryCache: QueryCacheEntry?

    private static let fuzzyPoolLimit = 320

    private static let lowerMap: [Character: Character] = [
        "`": "ё",
        "q": "й", "w": "ц", "e": "у", "r": "к", "t": "е", "y": "н", "u": "г", "i": "ш", "o": "щ", "p": "з",
        "[": "х", "]": "ъ",
        "a": "ф", "s": "ы", "d": "в", "f": "а", "g": "п", "h": "р", "j": "о", "k": "л", "l": "д",
        ";": "ж", "'": "э",
        "z": "я", "x": "ч", "c": "с", "v": "м", "b": "и", "n": "т", "m": "ь",
        ",": "б", ".": "ю", "/": "."
    ]

    private static let fallbackDictionary: [Candidate] = [
        makeCandidate(text: "привет", frequency: 520, source: .builtin, debugSummary: "来源: 系统词库"),
        makeCandidate(text: "спасибо", frequency: 510, source: .builtin, debugSummary: "来源: 系统词库"),
        makeCandidate(text: "пожалуйста", frequency: 500, source: .builtin, debugSummary: "来源: 系统词库")
    ]

    private static let transliterationMap: [Character: String] = [
        "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "yo",
        "ж": "zh", "з": "z", "и": "i", "й": "y", "к": "k", "л": "l", "м": "m",
        "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u",
        "ф": "f", "х": "h", "ц": "c", "ч": "ch", "ш": "sh", "щ": "shch",
        "ы": "y", "э": "e", "ю": "yu", "я": "ya", "ь": "", "ъ": ""
    ]
    private static let commonPrepositions: Set<String> = ["в", "во", "на", "с", "со", "к", "ко", "из", "у", "по", "о", "об", "от", "до", "за", "под", "при"]
    private static let commonPronouns: Set<String> = ["я", "ты", "он", "она", "мы", "вы", "они", "это", "этот", "эта", "мой", "твой", "наш", "ваш"]
    private static let commonInterjections: Set<String> = ["привет", "спасибо", "пока", "здравствуйте", "извините", "пожалуйста"]

    init(bundle: Bundle = .main) {
        let builtinDictionary = Self.loadDictionary(from: bundle)
        builtinIndex = Self.buildIndex(from: builtinDictionary)
        let phrases = Self.loadPhraseDictionary(from: bundle)
        let phraseIndexData = Self.buildPhraseIndex(from: phrases)
        phraseIndex = phraseIndexData.index
        globalPhrases = phraseIndexData.globals
        preferences = PreferencesStore.shared.preferences.sanitized
        customDictionaryFingerprint = Self.dictionaryFingerprint(for: preferences.customDictionaryText)
        customIndex = Self.buildIndex(from: Self.parseDictionary(preferences.customDictionaryText, source: .custom))
    }

    init(dictionaryText: String) {
        let parsed = Self.parseDictionary(dictionaryText)
        let builtinDictionary = parsed.isEmpty ? Self.fallbackDictionary : parsed
        builtinIndex = Self.buildIndex(from: builtinDictionary)
        let phrases = Self.loadPhraseDictionary(from: .main)
        let phraseIndexData = Self.buildPhraseIndex(from: phrases)
        phraseIndex = phraseIndexData.index
        globalPhrases = phraseIndexData.globals
        preferences = PreferencesStore.shared.preferences.sanitized
        customDictionaryFingerprint = Self.dictionaryFingerprint(for: preferences.customDictionaryText)
        customIndex = Self.buildIndex(from: Self.parseDictionary(preferences.customDictionaryText, source: .custom))
    }

    mutating func reloadPreferences() {
        let newPreferences = PreferencesStore.shared.preferences.sanitized
        let newFingerprint = Self.dictionaryFingerprint(for: newPreferences.customDictionaryText)
        let dictionaryChanged = newFingerprint != customDictionaryFingerprint

        preferences = newPreferences
        if dictionaryChanged {
            customDictionaryFingerprint = newFingerprint
            customIndex = Self.buildIndex(from: Self.parseDictionary(newPreferences.customDictionaryText, source: .custom))
            invalidateCaches()
        } else if queryCache?.preferences != newPreferences {
            queryCache = nil
        }
    }

    func mappedCharacter(for input: Character) -> Character? {
        if let mapped = Self.lowerMap[input] {
            return mapped
        }

        let lowercased = Character(String(input).lowercased())
        guard let mapped = Self.lowerMap[lowercased], String(input) != String(lowercased) else {
            return nil
        }

        return Character(String(mapped).uppercased())
    }

    func mappedText(for input: String) -> String? {
        let output = input.compactMap { mappedCharacter(for: $0) }
        guard output.count == input.count else {
            return nil
        }

        return String(output)
    }

    mutating func candidates(for input: String, previousWord: String? = nil, limit: Int = 8) -> [Candidate] {
        reloadPreferences()
        let normalizedInput = input.lowercased()
        guard !normalizedInput.isEmpty else {
            return []
        }

        let mappedPrefix = mappedText(for: input)?.lowercased()
        let fuzzyThreshold = preferences.enableAutoCorrection ? Self.fuzzyThreshold(for: normalizedInput) : 0
        let context = queryContext(for: normalizedInput, fuzzyThreshold: fuzzyThreshold)
        var scoredMatches: [MatchScore] = []

        for entry in context.pool {
            let candidate = entry.candidate
            let text = entry.textLower
            let transliteration = entry.transliteration
            let contextBonus = preferences.enablePrediction
                ? userLexicon.frequencyBonus(for: candidate.text, input: normalizedInput, previousWord: previousWord)
                : 0
            var bestScore: Int?
            var isMappedExact = false

            if transliteration.hasPrefix(normalizedInput) {
                let exactBonus = transliteration == normalizedInput ? 600 : 400
                bestScore = max(bestScore ?? .min, candidate.frequency + contextBonus + exactBonus)
            }

            if let mappedPrefix, text.hasPrefix(mappedPrefix) {
                let exactBonus = text == mappedPrefix ? 500 : 300
                bestScore = max(bestScore ?? .min, candidate.frequency + contextBonus + exactBonus)
                if text == mappedPrefix {
                    isMappedExact = true
                }
            }

            if let bestScore {
                let exactBonus = max(0, bestScore - candidate.frequency - contextBonus)
                scoredMatches.append(
                    MatchScore(
                        candidate: candidate.withDebugSummary(
                            Self.makeDebugSummary(
                                source: candidate.source,
                                baseFrequency: candidate.frequency,
                                exactBonus: exactBonus,
                                contextBonus: contextBonus,
                                fuzzyBonus: 0
                            )
                        ),
                        score: bestScore,
                        isMappedExact: isMappedExact
                    )
                )
            }
        }

        if fuzzyThreshold > 0 {
            for entry in context.fuzzyPool {
                let candidate = entry.candidate
                let contextBonus = preferences.enablePrediction
                    ? userLexicon.frequencyBonus(for: candidate.text, input: normalizedInput, previousWord: previousWord)
                    : 0

                if let fuzzyScore = Self.fuzzyScore(input: normalizedInput, candidateKey: entry.transliteration, threshold: fuzzyThreshold) {
                    scoredMatches.append(
                        MatchScore(
                            candidate: candidate.withSource(.fuzzy).withDebugSummary(
                                Self.makeDebugSummary(
                                    source: .fuzzy,
                                    baseFrequency: candidate.frequency,
                                    exactBonus: 0,
                                    contextBonus: contextBonus,
                                    fuzzyBonus: fuzzyScore
                                )
                            ),
                            score: candidate.frequency + contextBonus + fuzzyScore,
                            isMappedExact: false
                        )
                    )
                }
            }
        }

        var seen = Set<String>()
        var matches = scoredMatches
            .sorted(by: Self.compareMatches)
            .map(\.candidate)
            .filter { seen.insert($0.text.lowercased()).inserted }

        if let mappedPrefix, !mappedPrefix.isEmpty {
            let mappedCandidate = Self.makeCandidate(
                text: mappedPrefix,
                frequency: Int.max,
                source: .mapped,
                debugSummary: "来源: 映射 | 精确命中"
            )
            matches.removeAll { $0.text.lowercased() == mappedPrefix }
            matches.insert(mappedCandidate, at: 0)
        }

        let phraseCandidates = phraseSuggestions(for: normalizedInput, mappedPrefix: mappedPrefix, previousWord: previousWord)
        if !phraseCandidates.isEmpty {
            var phraseSeen = Set(matches.map { $0.text.lowercased() })
            for phrase in phraseCandidates {
                let key = phrase.text.lowercased()
                guard phraseSeen.insert(key).inserted else { continue }
                matches.append(phrase)
            }
            matches.sort { lhs, rhs in
                if lhs.frequency != rhs.frequency {
                    return lhs.frequency > rhs.frequency
                }
                if lhs.text.count != rhs.text.count {
                    return lhs.text.count < rhs.text.count
                }
                return lhs.text < rhs.text
            }
        }

        return Array(matches.prefix(limit))
    }

    mutating func previewText(for input: String, previousWord: String? = nil) -> String {
        reloadPreferences()
        return candidates(for: input, previousWord: previousWord, limit: 1).first?.text ?? mappedText(for: input) ?? input
    }

    mutating func learnSelection(_ text: String, for input: String, previousWord: String? = nil) {
        reloadPreferences()
        guard preferences.enableLearning else { return }
        userLexicon.recordSelection(text, input: input.lowercased(), previousWord: previousWord)
    }

    private static func compareMatches(_ lhs: MatchScore, _ rhs: MatchScore) -> Bool {
        if lhs.isMappedExact != rhs.isMappedExact {
            return lhs.isMappedExact
        }
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }
        if lhs.candidate.text.count != rhs.candidate.text.count {
            return lhs.candidate.text.count < rhs.candidate.text.count
        }
        return lhs.candidate.text < rhs.candidate.text
    }

    private static func makeCandidate(text: String, frequency: Int, source: Candidate.Source, debugSummary: String) -> Candidate {
        Candidate(
            text: text,
            frequency: frequency,
            annotation: annotation(for: text, source: source),
            partOfSpeech: partOfSpeech(for: text),
            source: source,
            debugSummary: debugSummary
        )
    }

    private static func annotation(for text: String, source: Candidate.Source) -> String {
        if text.contains(" ") {
            return source == .phrase ? "常用短语" : "多词表达"
        }
        switch source {
        case .mapped:
            return "键位直映"
        case .builtin:
            return "基础词条"
        case .custom:
            return "自定义词"
        case .learned:
            return "学习排序"
        case .phrase:
            return "固定搭配"
        case .fuzzy:
            return "纠错候选"
        }
    }

    private static func partOfSpeech(for text: String) -> String {
        let lower = text.lowercased()
        if lower.contains(" ") { return "PHR" }
        if commonInterjections.contains(lower) { return "INTJ" }
        if commonPrepositions.contains(lower) { return "PREP" }
        if commonPronouns.contains(lower) { return "PRON" }
        if lower.hasSuffix("ть") { return "VERB" }
        if lower.hasSuffix("ый") || lower.hasSuffix("ий") || lower.hasSuffix("ая") || lower.hasSuffix("ое") { return "ADJ" }
        if lower.hasSuffix("ость") || lower.hasSuffix("ение") || lower.hasSuffix("ция") || lower.hasSuffix("изм") { return "NOUN" }
        return "LEX"
    }

    private static func makeDebugSummary(source: Candidate.Source, baseFrequency: Int, exactBonus: Int, contextBonus: Int, fuzzyBonus: Int) -> String {
        var parts = ["来源: \(source.label)", "基础: \(baseFrequency)"]
        if exactBonus > 0 {
            parts.append("前缀: +\(exactBonus)")
        }
        if contextBonus > 0 {
            parts.append("上下文: +\(contextBonus)")
        }
        if fuzzyBonus > 0 {
            parts.append("纠错: +\(fuzzyBonus)")
        }
        return parts.joined(separator: " | ")
    }

    static func transliterationKey(for text: String) -> String {
        text.lowercased().reduce(into: "") { result, character in
            if let replacement = transliterationMap[character] {
                result += replacement
            } else {
                result.append(character)
            }
        }
    }

    private static func loadDictionary(from bundle: Bundle) -> [Candidate] {
        guard
            let url = bundle.url(forResource: "RussianDictionary", withExtension: "txt"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return fallbackDictionary
        }

        let parsed = parseDictionary(text, source: .builtin)
        return parsed.isEmpty ? fallbackDictionary : parsed
    }

    private static func parseDictionary(_ text: String, source: Candidate.Source = .builtin) -> [Candidate] {
        var candidates: [Candidate] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else {
                continue
            }

            let parts = line.split(whereSeparator: \.isWhitespace)
            guard let word = parts.first else {
                continue
            }

            let frequency = parts.dropFirst().first.flatMap { Int($0) } ?? 0
            candidates.append(
                makeCandidate(
                    text: String(word),
                    frequency: frequency,
                    source: source,
                    debugSummary: "来源: \(source.label)词库 | 频次 \(frequency)"
                )
            )
        }

        return candidates
    }

    private static func loadPhraseDictionary(from bundle: Bundle) -> [PhraseCandidate] {
        guard
            let url = bundle.url(forResource: "RussianPhrases", withExtension: "txt"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return []
        }

        return parsePhraseDictionary(text)
    }

    private static func parsePhraseDictionary(_ text: String) -> [PhraseCandidate] {
        var phrases: [PhraseCandidate] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else {
                continue
            }

            let parts = line.split(whereSeparator: \.isWhitespace)
            guard parts.count >= 2 else { continue }

            let frequency = Int(parts.last!) ?? 0
            let body = parts.dropLast().map(String.init)
            guard !body.isEmpty else { continue }

            let anchor = body.count >= 3 ? body.first?.lowercased() : nil
            let phraseWords = anchor == nil ? body : Array(body.dropFirst())
            let phraseText = phraseWords.joined(separator: " ")
            let normalized = phraseText.lowercased()

            phrases.append(
                PhraseCandidate(
                    anchor: anchor,
                    text: phraseText,
                    frequency: frequency,
                    normalizedText: normalized,
                    transliteration: transliterationKey(for: normalized)
                )
            )
        }

        return phrases
    }

    private static func buildPhraseIndex(from phrases: [PhraseCandidate]) -> (index: [String: [PhraseCandidate]], globals: [PhraseCandidate]) {
        var index: [String: [PhraseCandidate]] = [:]
        var globals: [PhraseCandidate] = []

        for phrase in phrases {
            if let anchor = phrase.anchor {
                index[anchor, default: []].append(phrase)
            } else {
                globals.append(phrase)
            }
        }

        return (index, globals)
    }

    private static func dictionaryFingerprint(for text: String) -> Int {
        var hasher = Hasher()
        hasher.combine(text)
        return hasher.finalize()
    }

    private static func buildIndex(from candidates: [Candidate]) -> DictionaryIndex {
        let entries = candidates.map { candidate in
            let textLower = candidate.text.lowercased()
            return DictionaryEntry(
                candidate: candidate,
                textLower: textLower,
                transliteration: transliterationKey(for: textLower)
            )
        }

        var buckets: [String: [DictionaryEntry]] = [:]
        for entry in entries {
            guard !entry.transliteration.isEmpty else { continue }

            let key1 = String(entry.transliteration.prefix(1))
            buckets[key1, default: []].append(entry)

            let key2 = String(entry.transliteration.prefix(2))
            if key2.count == 2 {
                buckets[key2, default: []].append(entry)
            }
        }

        return DictionaryIndex(entries: entries, buckets: buckets)
    }

    private func exactMatchEntries(for input: String) -> [DictionaryEntry] {
        var pool: [DictionaryEntry] = []
        let bucketKey = Self.prefixBucketKey(for: input)

        if preferences.enablePrediction {
            pool.append(contentsOf: learnedEntries())
        }

        if preferences.enableCustomDictionary {
            pool.append(contentsOf: customIndex.entries(for: bucketKey))
        }

        if preferences.enableBuiltinDictionary {
            pool.append(contentsOf: builtinIndex.entries(for: bucketKey))
        }

        if pool.isEmpty {
            pool = Self.buildIndex(from: Self.fallbackDictionary).entries
        }

        return deduplicatedEntries(pool)
    }

    private func fuzzyMatchEntries(for input: String) -> [DictionaryEntry] {
        let broadKey = String(input.prefix(1))
        var pool: [DictionaryEntry] = []

        if preferences.enableCustomDictionary {
            pool.append(contentsOf: customIndex.entries(for: broadKey))
        }

        if preferences.enableBuiltinDictionary {
            pool.append(contentsOf: builtinIndex.entries(for: broadKey))
        }

        return Array(deduplicatedEntries(pool).prefix(Self.fuzzyPoolLimit))
    }

    private func learnedEntries() -> [DictionaryEntry] {
        userLexicon.learnedWords
            .map { word in
                Self.makeCandidate(
                    text: word,
                    frequency: userLexicon.maxFrequencyBonus(for: word),
                    source: .learned,
                    debugSummary: "来源: 学习词库"
                )
            }
            .sorted { lhs, rhs in
                if lhs.frequency != rhs.frequency {
                    return lhs.frequency > rhs.frequency
                }
                return lhs.text < rhs.text
            }
            .map { candidate in
                let textLower = candidate.text.lowercased()
                return DictionaryEntry(
                    candidate: candidate,
                    textLower: textLower,
                    transliteration: Self.transliterationKey(for: textLower)
                )
            }
    }

    private func deduplicatedEntries(_ entries: [DictionaryEntry]) -> [DictionaryEntry] {
        var seen = Set<String>()
        return entries.filter { seen.insert($0.textLower).inserted }
    }

    private mutating func queryContext(for input: String, fuzzyThreshold: Int) -> QueryContext {
        if let queryCache,
           queryCache.input == input,
           queryCache.preferences == preferences,
           queryCache.customDictionaryFingerprint == customDictionaryFingerprint {
            return queryCache.context
        }

        if let queryCache,
           input.hasPrefix(queryCache.input),
           queryCache.preferences == preferences,
           queryCache.customDictionaryFingerprint == customDictionaryFingerprint {
            let narrowedPool = queryCache.context.pool.filter { entry in
                entry.transliteration.hasPrefix(input) || entry.textLower.hasPrefix(input)
            }
            let narrowedContext = QueryContext(
                pool: narrowedPool,
                fuzzyPool: fuzzyThreshold > 0 ? queryCache.context.fuzzyPool : []
            )
            self.queryCache = QueryCacheEntry(
                input: input,
                preferences: preferences,
                customDictionaryFingerprint: customDictionaryFingerprint,
                context: narrowedContext
            )
            return narrowedContext
        }

        let context = QueryContext(
            pool: exactMatchEntries(for: input),
            fuzzyPool: fuzzyThreshold > 0 ? fuzzyMatchEntries(for: input) : []
        )
        queryCache = QueryCacheEntry(
            input: input,
            preferences: preferences,
            customDictionaryFingerprint: customDictionaryFingerprint,
            context: context
        )
        return context
    }

    private mutating func invalidateCaches() {
        queryCache = nil
    }

    private func phraseSuggestions(for input: String, mappedPrefix: String?, previousWord: String?) -> [Candidate] {
        guard preferences.enablePrediction else { return [] }

        var pool: [PhraseCandidate] = globalPhrases
        if let previousWord {
            let previousKey = previousWord.lowercased()
            pool.append(contentsOf: phraseIndex[previousKey] ?? [])
            pool.append(contentsOf: userLexicon.learnedPhraseCandidates(after: previousKey))
        } else {
            pool.append(contentsOf: userLexicon.learnedPhraseCandidates(after: nil))
        }

        var seen = Set<String>()
        return pool
            .filter { phrase in
                phrase.transliteration.hasPrefix(input)
                    || phrase.normalizedText.hasPrefix(input)
                    || mappedPrefix.map { phrase.normalizedText.hasPrefix($0) } == true
            }
            .sorted {
                if $0.frequency != $1.frequency {
                    return $0.frequency > $1.frequency
                }
                return $0.text < $1.text
            }
            .filter { seen.insert($0.normalizedText).inserted }
            .map {
                Self.makeCandidate(
                    text: $0.text,
                    frequency: $0.frequency + 1200,
                    source: .phrase,
                    debugSummary: "来源: 短语 | 频次 \($0.frequency)"
                )
            }
    }

    private static func prefixBucketKey(for input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return String(trimmed.prefix(min(2, trimmed.count)))
    }

    private static func fuzzyThreshold(for input: String) -> Int {
        switch input.count {
        case 0...2: return 0
        case 3...5: return 1
        default: return 2
        }
    }

    private static func fuzzyScore(input: String, candidateKey: String, threshold: Int) -> Int? {
        guard threshold > 0, !input.isEmpty, !candidateKey.isEmpty else { return nil }

        let maxPrefixLength = min(candidateKey.count, input.count + threshold)
        let candidatePrefix = String(candidateKey.prefix(maxPrefixLength))
        let transpositionDistance = damerauLevenshteinDistance(input, candidatePrefix)
        let prefixDistance = prefixEditDistance(input: input, candidateKey: candidateKey, threshold: threshold)
        let distance = min(transpositionDistance, prefixDistance)
        guard distance > 0, distance <= threshold else { return nil }

        let baseScore = 170 - distance * 35
        let shortPenalty = input.count <= 4 ? 10 : 0
        return baseScore - shortPenalty
    }

    private static func prefixEditDistance(input: String, candidateKey: String, threshold: Int) -> Int {
        var best = Int.max
        let minLength = max(1, input.count - threshold)
        let maxLength = min(candidateKey.count, input.count + threshold)
        guard minLength <= maxLength else { return best }

        for length in minLength...maxLength {
            let prefix = String(candidateKey.prefix(length))
            best = min(best, damerauLevenshteinDistance(input, prefix))
        }

        return best
    }

    private static func damerauLevenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)

        guard !lhsChars.isEmpty else { return rhsChars.count }
        guard !rhsChars.isEmpty else { return lhsChars.count }

        var matrix = Array(
            repeating: Array(repeating: 0, count: rhsChars.count + 1),
            count: lhsChars.count + 1
        )

        for row in 0...lhsChars.count {
            matrix[row][0] = row
        }

        for column in 0...rhsChars.count {
            matrix[0][column] = column
        }

        for row in 1...lhsChars.count {
            for column in 1...rhsChars.count {
                let substitutionCost = lhsChars[row - 1] == rhsChars[column - 1] ? 0 : 1
                var distance = min(
                    matrix[row - 1][column] + 1,
                    matrix[row][column - 1] + 1,
                    matrix[row - 1][column - 1] + substitutionCost
                )

                if row > 1,
                   column > 1,
                   lhsChars[row - 1] == rhsChars[column - 2],
                   lhsChars[row - 2] == rhsChars[column - 1] {
                    distance = min(distance, matrix[row - 2][column - 2] + 1)
                }

                matrix[row][column] = distance
            }
        }

        return matrix[lhsChars.count][rhsChars.count]
    }
}

private struct UserLexiconStore {
    private struct PersistedLexicon: Codable {
        var version: Int
        var wordScores: [String: Int]
        var inputWordScores: [String: [String: Int]]
        var bigramScores: [String: [String: Int]]
        var phraseScores: [String: [String: Int]]
        var recentSelections: [RecentSelection]
    }

    private struct RecentSelection: Codable, Equatable {
        var word: String
        var previousWord: String?
        var sequence: Int
    }

    private static let schemaVersion = 3
    private static let flushDelay: TimeInterval = 1.5
    private static let maxWordBonus = 120
    private static let maxInputBonus = 260
    private static let maxBigramBonus = 360
    private static let maxRecentBonus = 280
    private static let phraseStep = 140
    private static let wordStep = 12
    private static let inputStep = 36
    private static let bigramStep = 80
    private static let recentWindow = 24

    private var wordScores: [String: Int]
    private var inputWordScores: [String: [String: Int]]
    private var bigramScores: [String: [String: Int]]
    private var phraseScores: [String: [String: Int]]
    private var recentSelections: [RecentSelection]
    private var selectionSequence: Int
    private let storageURL: URL?
    private let backupURL: URL?
    private var pendingFlushWorkItem: DispatchWorkItem?
    private let flushQueue = DispatchQueue(label: "com.znak.userlexicon.flush", qos: .utility)

    init(fileManager: FileManager = .default) {
        storageURL = Self.makeStorageURL(fileManager: fileManager)
        backupURL = storageURL?.deletingLastPathComponent().appendingPathComponent("user_dictionary.backup.json")

        let persisted = Self.load(from: storageURL, backupURL: backupURL)
        wordScores = persisted.wordScores
        inputWordScores = persisted.inputWordScores
        bigramScores = persisted.bigramScores
        phraseScores = persisted.phraseScores
        recentSelections = persisted.recentSelections
        selectionSequence = persisted.recentSelections.map(\.sequence).max() ?? 0
        sanitizeAndRepairIfNeeded()
    }

    var learnedWords: [String] {
        let allWords = Set(wordScores.keys).union(
            inputWordScores.values.flatMap { $0.keys }
        )
        return allWords.sorted()
    }

    func maxFrequencyBonus(for word: String) -> Int {
        let key = word.lowercased()
        let contextMax = inputWordScores.values.compactMap { $0[key] }.max() ?? 0
        let bigramMax = bigramScores.values.compactMap { $0[key] }.max() ?? 0
        return min(Self.maxWordBonus, wordScores[key] ?? 0)
            + min(Self.maxInputBonus, contextMax)
            + min(Self.maxBigramBonus, bigramMax)
            + recentBonus(for: key, previousWord: nil)
    }

    func frequencyBonus(for word: String, input: String, previousWord: String?) -> Int {
        let key = word.lowercased()
        let inputKey = Self.normalizedInputKey(input)
        let globalBonus = min(Self.maxWordBonus, wordScores[key] ?? 0)
        let contextualBonus = min(Self.maxInputBonus, inputWordScores[inputKey]?[key] ?? 0)
        let previousKey = previousWord.flatMap(Self.normalizedWordKey)
        let bigramBonus = previousKey
            .flatMap { bigramScores[$0]?[key] }
            .map { min(Self.maxBigramBonus, $0) } ?? 0
        let recencyBonus = recentBonus(for: key, previousWord: previousKey)
        return globalBonus + contextualBonus + bigramBonus + recencyBonus
    }

    mutating func recordSelection(_ word: String, input: String, previousWord: String?) {
        guard Self.isLearnable(word), Self.isLearnableInput(input) else { return }

        let wordKey = word.lowercased()
        let inputKey = Self.normalizedInputKey(input)
        wordScores[wordKey, default: 0] += Self.wordStep
        var inputScores = inputWordScores[inputKey] ?? [:]
        inputScores[wordKey, default: 0] += Self.inputStep
        inputWordScores[inputKey] = inputScores
        if let previousKey = previousWord.flatMap(Self.normalizedWordKey) {
            var pairScores = bigramScores[previousKey] ?? [:]
            pairScores[wordKey, default: 0] += Self.bigramStep
            bigramScores[previousKey] = pairScores
            if wordKey.contains(" ") {
                var phrases = phraseScores[previousKey] ?? [:]
                phrases[wordKey, default: 0] += Self.phraseStep
                phraseScores[previousKey] = phrases
            }
        }
        selectionSequence += 1
        recentSelections.append(RecentSelection(word: wordKey, previousWord: previousWord.flatMap(Self.normalizedWordKey), sequence: selectionSequence))
        if recentSelections.count > Self.recentWindow {
            recentSelections.removeFirst(recentSelections.count - Self.recentWindow)
        }
        scheduleFlush()
    }

    private mutating func scheduleFlush() {
        pendingFlushWorkItem?.cancel()

        let snapshot = PersistedLexicon(
            version: Self.schemaVersion,
            wordScores: wordScores,
            inputWordScores: inputWordScores,
            bigramScores: bigramScores,
            phraseScores: phraseScores,
            recentSelections: recentSelections
        )

        let workItem = DispatchWorkItem { [storageURL, backupURL] in
            guard let storageURL,
                  let data = try? JSONEncoder().encode(snapshot) else {
                return
            }

            do {
                if let backupURL,
                   FileManager.default.fileExists(atPath: storageURL.path) {
                    try? FileManager.default.removeItem(at: backupURL)
                    try? FileManager.default.copyItem(at: storageURL, to: backupURL)
                }
                try data.write(to: storageURL, options: .atomic)
            } catch {
                NSLog("[Znak] Failed to persist user lexicon: \(error.localizedDescription)")
            }
        }

        pendingFlushWorkItem = workItem
        flushQueue.asyncAfter(deadline: .now() + Self.flushDelay, execute: workItem)
    }

    private static func load(from url: URL?, backupURL: URL?) -> PersistedLexicon {
        if let persisted = loadPersistedLexicon(from: url) {
            return persisted
        }

        if let backup = loadPersistedLexicon(from: backupURL) {
            if let url, let data = try? JSONEncoder().encode(backup) {
                try? data.write(to: url, options: .atomic)
            }
            NSLog("[Znak] Restored user lexicon from backup")
            return backup
        }

        if let url,
           let legacyData = try? Data(contentsOf: url),
           let legacy = try? JSONDecoder().decode([String: Int].self, from: legacyData) {
            return PersistedLexicon(
                version: schemaVersion,
                wordScores: legacy,
                inputWordScores: [:],
                bigramScores: [:],
                phraseScores: [:],
                recentSelections: []
            )
        }

        if let url,
           FileManager.default.fileExists(atPath: url.path) {
            let damagedURL = url.deletingLastPathComponent().appendingPathComponent("user_dictionary.damaged-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: damagedURL)
            NSLog("[Znak] Moved damaged user lexicon to \(damagedURL.path)")
        }

        return PersistedLexicon(version: schemaVersion, wordScores: [:], inputWordScores: [:], bigramScores: [:], phraseScores: [:], recentSelections: [])
    }

    private static func loadPersistedLexicon(from url: URL?) -> PersistedLexicon? {
        guard let url,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(PersistedLexicon.self, from: data) else {
            return nil
        }
        return decoded
    }

    private static func makeStorageURL(fileManager: FileManager) -> URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let directory = appSupport.appendingPathComponent("Znak", isDirectory: true)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            NSLog("[Znak] Failed to create user lexicon directory: \(error.localizedDescription)")
            return nil
        }

        return directory.appendingPathComponent("user_dictionary.json")
    }

    private mutating func sanitizeAndRepairIfNeeded() {
        let sanitizedWordScores = wordScores.filter { Self.isLearnable($0.key) && $0.value > 0 }
        let sanitizedInputScores = inputWordScores.reduce(into: [String: [String: Int]]()) { result, entry in
            let inputKey = Self.normalizedInputKey(entry.key)
            guard Self.isLearnableInput(inputKey) else { return }

            let sanitizedWords = entry.value.filter { Self.isLearnable($0.key) && $0.value > 0 }
            guard !sanitizedWords.isEmpty else { return }
            result[inputKey] = sanitizedWords
        }
        let sanitizedBigramScores = bigramScores.reduce(into: [String: [String: Int]]()) { result, entry in
            guard Self.isLearnable(entry.key) else { return }
            let sanitizedWords = entry.value.filter { Self.isLearnable($0.key) && $0.value > 0 }
            guard !sanitizedWords.isEmpty else { return }
            result[entry.key] = sanitizedWords
        }
        let sanitizedPhraseScores = phraseScores.reduce(into: [String: [String: Int]]()) { result, entry in
            guard Self.isLearnable(entry.key) else { return }
            let sanitizedWords = entry.value.filter { Self.isLearnablePhrase($0.key) && $0.value > 0 }
            guard !sanitizedWords.isEmpty else { return }
            result[entry.key] = sanitizedWords
        }
        let sanitizedRecentSelections = recentSelections.filter {
            Self.isLearnable($0.word) && ($0.previousWord == nil || Self.isLearnable($0.previousWord!))
        }.suffix(Self.recentWindow)

        guard sanitizedWordScores != wordScores
            || sanitizedInputScores != inputWordScores
            || sanitizedBigramScores != bigramScores
            || sanitizedPhraseScores != phraseScores
            || Array(sanitizedRecentSelections) != recentSelections
        else {
            return
        }

        wordScores = sanitizedWordScores
        inputWordScores = sanitizedInputScores
        bigramScores = sanitizedBigramScores
        phraseScores = sanitizedPhraseScores
        recentSelections = Array(sanitizedRecentSelections)
        scheduleFlush()
    }

    private static func normalizedInputKey(_ input: String) -> String {
        input.lowercased()
    }

    private static func normalizedWordKey(_ word: String) -> String? {
        let key = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return isLearnable(key) ? key : nil
    }

    func learnedPhraseCandidates(after previousWord: String?) -> [InputEngine.PhraseCandidate] {
        let previousKey = previousWord.flatMap(Self.normalizedWordKey)
        let phrases = previousKey.flatMap { phraseScores[$0] } ?? [:]
        return phrases.map { phrase, score in
            InputEngine.PhraseCandidate(
                anchor: previousKey,
                text: phrase,
                frequency: score,
                normalizedText: phrase.lowercased(),
                transliteration: InputEngine.transliterationKey(for: phrase.lowercased())
            )
        }
    }

    private func recentBonus(for word: String, previousWord: String?) -> Int {
        guard !recentSelections.isEmpty else { return 0 }
        var bonus = 0
        for selection in recentSelections.reversed() {
            guard selection.word == word else { continue }
            let age = selectionSequence - selection.sequence
            let base = max(0, 120 - age * 8)
            if base == 0 { continue }
            if previousWord != nil && selection.previousWord == previousWord {
                bonus += base + 18
            } else {
                bonus += base / 2
            }
        }
        return min(Self.maxRecentBonus, bonus)
    }

    private static func isLearnable(_ word: String) -> Bool {
        let lowered = word.lowercased()
        guard lowered.count >= 2 else { return false }
        return lowered.unicodeScalars.allSatisfy { scalar in
            CharacterSet(charactersIn: "\u{0400}"..."\u{04FF}").contains(scalar)
        }
    }

    private static func isLearnablePhrase(_ phrase: String) -> Bool {
        let parts = phrase.split(separator: " ")
        guard parts.count >= 2 else { return false }
        return parts.allSatisfy { isLearnable(String($0)) }
    }

    private static func isLearnableInput(_ input: String) -> Bool {
        let lowered = input.lowercased()
        guard (2...20).contains(lowered.count) else { return false }
        return lowered.unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0) }
    }
}
