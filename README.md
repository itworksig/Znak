# Znak

[中文说明](README.zh-CN.md) · [Русская версия](README.ru.md)

Znak is a native macOS Input MethodKit keyboard for fast Russian input on a QWERTY keyboard. It maps Latin key positions to the Russian keyboard layout, provides dictionary and phrase candidates, learns from user selections, and ships with a native AppKit preferences window.

Current version: `1.0.3`.


<img width="919" height="253" alt="image" src="https://github.com/user-attachments/assets/fdc96e6b-985c-4d9f-aa6f-2281715bc424" />

<img width="1474" height="852" alt="image" src="https://github.com/user-attachments/assets/b44ce0c8-db0f-41b2-9a77-ae48a2998473" />


## Highlights

- QWERTY key-position mapping to Russian characters.
- Built-in Russian dictionary and phrase dictionary.
- Optional Latin transliteration prediction.
- Fuzzy candidates for small typos.
- User learning with frequency, context, recency, migration, backup, repair, and decay.
- Candidate ranking preferences: common words, direct mapping, or phrases first.
- Horizontal and vertical candidate window layouts.
- Configurable candidate count and font size.
- Held Shift produces uppercase Russian.
- Standalone Shift tap toggles English passthrough mode.
- Configurable Caps Lock behavior.
- Custom dictionary import/export.
- Settings window with installed version and GitHub Releases update checker.
- GitHub Actions release workflow for universal macOS `.app.zip` and `.pkg` artifacts.

## Repository Layout

```text
.
├── VERSION
├── README.md
├── README.zh-CN.md
├── README.ru.md
├── Znak.xcodeproj
├── Znak
│   ├── AppDelegate.swift
│   ├── CandidateWindowController.swift
│   ├── Info.plist
│   ├── InputController.swift
│   ├── InputControllerBehavior.swift
│   ├── InputEngine.swift
│   ├── Preferences.swift
│   ├── PreferencesWindowController.swift
│   ├── RussianDictionary.txt
│   ├── RussianPhrases.txt
│   ├── Znak.pdf
│   ├── ZnakMenuIcon.png
│   ├── en.lproj/InfoPlist.strings
│   ├── zh-Hans.lproj/InfoPlist.strings
│   └── main.swift
├── ZnakTests
│   ├── InputControllerBehaviorTests.swift
│   ├── InputEnginePerformanceTests.swift
│   └── InputEngineTests.swift
├── .github/workflows/release.yml
└── script/build_and_run.sh
```

## Architecture

Znak is intentionally small and native. There is no package manager, no external runtime, and no service process. The input method is an AppKit bundle app installed into a macOS Input Methods folder.

### Input Method Shell

`main.swift` starts the application and registers the Input MethodKit server. `AppDelegate.swift` owns the menu bar status item, settings entry point, quit action, and input-mode status label.

Install locations:

- User install: `~/Library/Input Methods/Znak.app`
- System install: `/Library/Input Methods/Znak.app`

The release `.pkg` installs into `/Library/Input Methods`.

### IMK Controller

`InputController.swift` is the production `IMKInputController`. It bridges macOS text clients to the engine and candidate UI.

Responsibilities:

- Translate keyboard events into composition updates.
- Track raw input, marked text, candidates, selected index, and page offset.
- Commit selected candidates or fallback text.
- Hide stale candidate windows when the active client changes.
- Clear composition when applications or text areas lose focus.
- Resolve cursor rectangles from IMK clients and use stable fallback positions when unavailable.
- Persist global or per-app input mode state when the preference is enabled.
- Avoid unsafe KVC crashes when inferring app context.

### Behavior Core

`InputControllerBehavior.swift` mirrors key input behavior without a real `IMKTextInput`. This keeps user-facing behavior testable in normal XCTest.

Covered behavior includes empty-candidate fallback commits, number-key selection, page navigation, held Shift uppercase Russian, standalone Shift English toggling, Caps Lock modes, and preference-change candidate refresh.

### Input Engine

`InputEngine.swift` is the AppKit-free core. Preferences, dictionary text, phrase text, and learning stores are injected instead of read directly from user defaults. This keeps tests deterministic and prevents test runs from touching real user learning data.

The engine handles keyboard mapping, dictionary parsing and indexing, phrase indexing, layered ranking, fuzzy matching, preview text, selection learning, and user lexicon persistence.

## Candidate Sources

`InputEngine.Candidate.Source` describes candidate origin:

- `builtin`: bundled dictionary entry.
- `custom`: user custom dictionary entry.
- `learned`: user-learned word.
- `phrase`: phrase candidate.
- `fuzzy`: typo-tolerant candidate.
- `mapped`: direct keyboard-layout mapping fallback.

These sources also drive candidate debug labels and source tags in the candidate window.

## Candidate Ranking

Ranking is explicitly layered so behavior is predictable. For example, when typing `ghb`, whether the first candidate is `привет`, `приказ`, or `при` is controlled by the ranking preference instead of accidental score mixing.

### `commonWords`

Default mode for daily typing:

1. Exact dictionary matches from built-in, custom, and learned dictionaries.
2. User learning and previous-word context bonuses inside the dictionary layer.
3. Phrase suggestions.
4. Fuzzy typo candidates.
5. Direct mapped fallback only when no stronger candidate exists.

### `directMapping`

Places the raw keyboard-layout mapping first. This is useful for users who expect the method to behave like a strict Russian keyboard layout with candidates as assistance.

### `phrases`

Promotes phrase suggestions before dictionary completions. This is useful for repetitive expressions and phrase-heavy typing.

## Learning System

`UserLexiconStore` conforms to `InputLearningStore` and stores JSON learning data in the app support directory. It records word frequency, input-to-word scores, previous-word bigram scores, phrase scores, recent selections, a schema version, and a selection sequence.

The current schema version is `4`.

The store avoids learning punctuation, phrases as single words, abnormal input, and invalid non-word values. It periodically decays old frequencies so early mistakes do not permanently outrank newer habits. Writes keep a backup, and load logic repairs or migrates older data when possible.

When learning data is reset from preferences, active engines reload the learning store immediately.

## Preferences

Preferences are represented by `InputPreferences` in `Preferences.swift` and persisted by `PreferencesStore`.

Important fields:

- `latinPredictionEnabled`: enables Latin transliteration prediction.
- `customDictionaryText`: newline-based custom dictionary.
- `preeditStyle`: marked text style.
- `themePreset`: candidate theme.
- `maxCandidateCount`: candidate cap.
- `candidateRankingPreference`: common words, direct mapping, or phrases first.
- `candidateLayout`: horizontal or vertical candidate window.
- `candidateFontSize`: candidate text size.
- `capsLockBehavior`: passthrough, English toggle, or uppercase Russian.
- `persistInputModeState`: persist input mode globally and by app.
- `showCandidateSourceDebug`: display candidate source/debug information.

`PreferencesWindowController.swift` implements the settings window with native AppKit controls.

## Input Modes

Znak has Russian mode and English passthrough mode. Russian mode maps keys and shows candidates. English mode passes keys through unchanged.

Held Shift does not switch to English. It produces uppercase Russian while staying in Russian mode. Tap and release Shift by itself to toggle English passthrough mode.

Caps Lock can pass through, toggle English mode, or produce uppercase Russian depending on preferences.

## Candidate Window

`CandidateWindowController.swift` implements a custom AppKit candidate panel using `NSPanel` and custom drawing.

It supports themes, horizontal/vertical layouts, configurable font size, candidate source tags, mode badges, page badges, toast messages, stable fallback positioning, fullscreen-friendly collection behavior, and multi-display placement.

AppKit window and view access must stay on the main thread/main actor. This matters especially for Xcode 16 release builds, which enforce AppKit isolation more strictly.

## Dictionaries

`Znak/RussianDictionary.txt` is the bundled word dictionary. Entries may include optional frequencies.

`Znak/RussianPhrases.txt` is the bundled phrase dictionary. Phrases are indexed by prefix and context, and can also appear as global phrase suggestions.

The custom dictionary is stored in preferences and can be edited, imported, or exported from the settings window. It is not written into the app bundle.

## Update Checking

The settings window queries:

```text
https://api.github.com/repos/itworksig/Znak/releases/latest
```

It compares the installed `CFBundleShortVersionString` with the latest release tag. If the installed version is current, it shows a Chinese/English/Russian “up to date” message. If a newer version exists, it downloads the `.pkg` asset to `~/Downloads` and opens it.

Release artifact names follow this convention:

```text
Znak-<version>-macos-universal.pkg
Znak-<version>-macos-universal.app.zip
SHA256SUMS.txt
```

## Requirements

Development:

- macOS.
- Xcode 16 recommended for release builds.
- Xcode 15.4 can build when `SWIFT_VERSION=5.0` is supplied.
- Swift 5 language mode.

Runtime:

- macOS 13 or later for current release builds.
- Input MethodKit, included with macOS.

## Build

Debug build:

```bash
xcodebuild \
  -project Znak.xcodeproj \
  -scheme Znak \
  -configuration Debug \
  -derivedDataPath /tmp/ZnakDerivedData \
  build
```

Universal release build:

```bash
xcodebuild \
  -project Znak.xcodeproj \
  -scheme Znak \
  -configuration Release \
  -derivedDataPath /tmp/ZnakDerivedDataRelease \
  -destination 'generic/platform=macOS' \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY='-' \
  CODE_SIGN_STYLE=Manual \
  MARKETING_VERSION='1.0.3' \
  CURRENT_PROJECT_VERSION='1' \
  SWIFT_VERSION='5.0' \
  clean build
```

## Local Install

After building to `/tmp/ZnakDerivedData`:

```bash
killall Znak 2>/dev/null || true
sleep 0.8
rm -rf "$HOME/Library/Input Methods/Znak.app"
cp -R "/tmp/ZnakDerivedData/Build/Products/Debug/Znak.app" "$HOME/Library/Input Methods/Znak.app"
open "$HOME/Library/Input Methods/Znak.app"
```

Then enable Znak in System Settings > Keyboard > Input Sources.

## Tests

Run all tests:

```bash
xcodebuild test \
  -project Znak.xcodeproj \
  -scheme Znak \
  -derivedDataPath /tmp/ZnakDerivedDataTests
```

Test groups:

- `InputEngineTests`: mapping, dictionary candidates, transliteration, fuzzy matching, phrases, ranking preferences, preference decoding, lexicon migration, and learning filters.
- `InputControllerBehaviorTests`: behavior-level tests without real IMK clients.
- `InputEnginePerformanceTests`: benchmark coverage for incremental lookup, fuzzy pools, phrase lookup, and large learned dictionaries.

## Release Workflow

`.github/workflows/release.yml` triggers on pushes to `main` that change `VERSION` or the workflow file, and on manual dispatch.

Release steps:

1. Read and validate `VERSION`.
2. Compute tag `v<version>`.
3. Skip if the tag exists.
4. Generate release notes from commits.
5. Select Xcode.
6. Build a universal macOS app.
7. Package `.app.zip`, `.pkg`, and `SHA256SUMS.txt`.
8. Create an annotated git tag.
9. Publish GitHub Release assets.

Use `feat:` and `fix:` commit prefixes for cleaner release notes. Other commits are grouped under Changes.

## Versioning

`VERSION` is the source of truth for releases. `Info.plist` reads `$(MARKETING_VERSION)`, so the settings window displays the Xcode marketing version.

For a release, update `VERSION`, update `MARKETING_VERSION` in `Znak.xcodeproj/project.pbxproj`, commit, and push to `main`.

## Developer Notes

- Keep `InputEngine` independent from AppKit and concrete user defaults.
- Prefer dependency injection for preferences, dictionaries, phrases, and learning stores.
- Put testable key behavior into `InputControllerBehavior` before bridging it in `InputController`.
- Treat candidate ordering as user-visible behavior and add tests for ranking changes.
- Keep AppKit access on the main thread/main actor.
- Do not learn punctuation, phrases as single words, abnormal input, or invalid text.
- Watch candidate latency when dictionaries or learned data grow.

## Troubleshooting

If Znak does not appear in Input Sources, confirm the app is installed in an Input Methods folder, open it once, and consider logging out if macOS caches the old list.

If only Latin letters are typed, Znak is probably in English passthrough mode. Tap Shift once to return to Russian mode.

If held Shift does not toggle English, that is intentional: held Shift inputs uppercase Russian; standalone Shift toggles English mode.

If the candidate window appears in the wrong place, the host app may be returning an invalid cursor rectangle. Znak falls back to the visible screen frame.

If GitHub Actions does not release, confirm the push is to `main`, `VERSION` changed or the workflow was manually dispatched, the tag does not already exist, and `contents: write` permission is available.

## Contributing

Keep changes scoped, add tests for input behavior and ranking changes, preserve the native AppKit approach, avoid unnecessary dependencies, run the full XCTest suite before release changes, and use clear commit prefixes such as `feat:` and `fix:`.
