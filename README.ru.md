# Znak

[English](README.md) · [中文说明](README.zh-CN.md)

Znak — это нативный macOS-метод ввода на базе Input MethodKit для быстрого русского ввода с QWERTY-клавиатуры. Он сопоставляет латинские клавиши с русской раскладкой, показывает словарные и фразовые кандидаты, обучается на выборе пользователя и предоставляет нативное окно настроек AppKit.

Текущая версия: `1.0.2`.

## Возможности

- Сопоставление QWERTY-клавиш с русскими символами.
- Встроенный русский словарь и словарь фраз.
- Опциональное предсказание по латинской транслитерации.
- Нечеткие кандидаты для небольших опечаток.
- Пользовательское обучение: частота, контекст, недавний выбор, миграция, backup, repair и decay.
- Предпочтения ранжирования: частые слова, прямое сопоставление или фразы первыми.
- Горизонтальное и вертикальное окно кандидатов.
- Настраиваемое количество кандидатов и размер шрифта.
- Удержание Shift вводит русские заглавные буквы.
- Одиночное нажатие Shift переключает английский passthrough-режим.
- Настраиваемое поведение Caps Lock.
- Импорт и экспорт пользовательского словаря.
- Окно настроек показывает установленную версию и проверяет GitHub Releases.
- GitHub Actions собирает универсальные macOS `.app.zip` и `.pkg`.

## Структура репозитория

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

## Архитектура

Znak — небольшой нативный AppKit/Input MethodKit проект без package manager, внешнего runtime и серверной части. Метод ввода — это AppKit bundle, установленный в папку macOS Input Methods.

### Оболочка метода ввода

`main.swift` запускает приложение и регистрирует Input MethodKit server. `AppDelegate.swift` отвечает за menu bar item, вход в настройки, выход и индикатор режима.

Пути установки:

- Пользовательский: `~/Library/Input Methods/Znak.app`
- Системный: `/Library/Input Methods/Znak.app`

Release `.pkg` устанавливает приложение в `/Library/Input Methods`.

### IMK-контроллер

`InputController.swift` — production `IMKInputController`, который связывает text clients macOS, движок ввода и окно кандидатов.

Обязанности:

- Преобразовывать клавиатурные события в обновления composition.
- Хранить raw input, marked text, кандидатов, выделенный индекс и страницу.
- Фиксировать выбранного кандидата или fallback-текст.
- Скрывать старое окно кандидатов при смене клиента.
- Очищать composition при потере фокуса приложением или текстовым полем.
- Получать cursor rect из IMK client и использовать fallback при ошибке.
- Сохранять global/per-app input mode state, если включена настройка.
- Избегать небезопасного KVC при определении app context.

### Тестируемое ядро поведения

`InputControllerBehavior.swift` выносит ключевые правила ввода из настоящего `IMKTextInput`, чтобы XCTest мог проверять пользовательские сценарии без системной сессии метода ввода.

Покрыты fallback commits при пустых кандидатах, выбор цифрами, page navigation, Shift для русских заглавных, одиночный Shift для английского режима, Caps Lock и обновление кандидатов после изменения настроек.

### Движок ввода

`InputEngine.swift` — ядро без AppKit. Preferences, dictionary text, phrase text и learning store передаются через dependency injection, а не читаются напрямую из user defaults. Это делает тесты стабильными и защищает реальные пользовательские данные.

Движок отвечает за keyboard mapping, parsing/indexing словаря, phrase indexing, layered ranking, fuzzy matching, preview text, selection learning и persistence пользовательского lexicon.

## Источники кандидатов

`InputEngine.Candidate.Source` описывает происхождение кандидата:

- `builtin`: встроенный словарь.
- `custom`: пользовательский словарь.
- `learned`: обученное слово.
- `phrase`: фразовый кандидат.
- `fuzzy`: исправление опечатки.
- `mapped`: fallback прямого сопоставления.

Эти значения используются для debug labels в окне кандидатов.

## Ранжирование кандидатов

Ранжирование разделено на понятные слои. Для ввода вроде `ghb` порядок `привет`, `приказ` или `при` задается предпочтением, а не случайным смешиванием scores.

### `commonWords`

Режим по умолчанию:

1. Точные совпадения из встроенного, пользовательского и обученного словаря.
2. Бонусы обучения и previous-word context внутри словарного слоя.
3. Фразовые подсказки.
4. Нечеткие кандидаты.
5. Прямое сопоставление только если нет более сильных кандидатов.

### `directMapping`

Ставит прямое сопоставление клавиш первым. Подходит пользователям, которые хотят поведение ближе к обычной русской раскладке.

### `phrases`

Поднимает фразы выше словарных дополнений. Полезно для устойчивых выражений и повторяющегося текста.

## Обучение

`UserLexiconStore` реализует `InputLearningStore` и хранит JSON в App Support. Он записывает word frequency, input-to-word scores, previous-word bigram scores, phrase scores, recent selections, schema version и selection sequence.

Текущая schema version: `4`.

Система не обучается на пунктуации, фразах как одиночных словах, аномальном input и некорректном тексте. Старые scores периодически уменьшаются, чтобы ранние ошибки не оставались наверху навсегда. Перед записью сохраняется backup, а загрузка умеет repair/migration старых данных.

После очистки обучения в настройках активные движки сразу reload learning store.

## Настройки

Настройки описаны `InputPreferences` в `Preferences.swift` и сохраняются через `PreferencesStore`.

Важные поля:

- `latinPredictionEnabled`: предсказание по латинской транслитерации.
- `customDictionaryText`: пользовательский словарь.
- `preeditStyle`: стиль marked text.
- `themePreset`: тема окна кандидатов.
- `maxCandidateCount`: лимит кандидатов.
- `candidateRankingPreference`: предпочтение ранжирования.
- `candidateLayout`: горизонтальное или вертикальное окно.
- `candidateFontSize`: размер шрифта кандидатов.
- `capsLockBehavior`: поведение Caps Lock.
- `persistInputModeState`: сохранение режима globally/per-app.
- `showCandidateSourceDebug`: показ источников/debug-информации кандидатов.

`PreferencesWindowController.swift` реализует окно настроек на нативном AppKit.

## Режимы ввода

Есть русский режим и английский passthrough-режим. Русский режим сопоставляет клавиши и показывает кандидатов. Английский режим передает символы напрямую.

Удержание Shift не переключает английский: оно вводит русские заглавные буквы. Одиночное нажатие и отпускание Shift переключает английский режим.

Caps Lock можно настроить как passthrough, переключение английского режима или русские заглавные буквы.

## Окно кандидатов

`CandidateWindowController.swift` реализует окно через `NSPanel` и custom drawing.

Поддерживаются темы, horizontal/vertical layout, размер шрифта, source tags, mode badge, page badge, toast messages, fallback positioning, несколько мониторов и fullscreen apps.

Доступ к AppKit window/view должен оставаться на main thread/main actor, особенно в Xcode 16 release builds.

## Словари

`Znak/RussianDictionary.txt` — встроенный словарь; записи могут иметь частоты.

`Znak/RussianPhrases.txt` — словарь фраз, индексируемый по prefix/context, также возможны global phrases.

Пользовательский словарь хранится в preferences. Его можно редактировать, импортировать и экспортировать в настройках. Он не записывается в app bundle.

## Проверка обновлений

Окно настроек запрашивает:

```text
https://api.github.com/repos/itworksig/Znak/releases/latest
```

Проверка сравнивает установленный `CFBundleShortVersionString` с последним release tag. Если версия актуальна, показывается сообщение на китайском, английском и русском. Если есть новая версия, `.pkg` скачивается в `~/Downloads` и открывается.

Имена release artifacts:

```text
Znak-<version>-macos-universal.pkg
Znak-<version>-macos-universal.app.zip
SHA256SUMS.txt
```

## Требования

Для разработки нужен macOS. Xcode 16 рекомендуется для release builds. Xcode 15.4 может собрать проект с явным `SWIFT_VERSION=5.0`. Текущий release deployment target — macOS 13 или новее.

## Сборка

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
  MARKETING_VERSION='1.0.2' \
  CURRENT_PROJECT_VERSION='1' \
  SWIFT_VERSION='5.0' \
  clean build
```

## Локальная установка

После сборки в `/tmp/ZnakDerivedData`:

```bash
killall Znak 2>/dev/null || true
sleep 0.8
rm -rf "$HOME/Library/Input Methods/Znak.app"
cp -R "/tmp/ZnakDerivedData/Build/Products/Debug/Znak.app" "$HOME/Library/Input Methods/Znak.app"
open "$HOME/Library/Input Methods/Znak.app"
```

Затем включите Znak в System Settings > Keyboard > Input Sources.

## Тесты

```bash
xcodebuild test \
  -project Znak.xcodeproj \
  -scheme Znak \
  -derivedDataPath /tmp/ZnakDerivedDataTests
```

Тесты включают `InputEngineTests`, `InputControllerBehaviorTests` и `InputEnginePerformanceTests`.

## Release workflow

`.github/workflows/release.yml` запускается при push в `main`, если изменен `VERSION` или workflow file, а также вручную.

Workflow читает `VERSION`, создает tag `v<version>`, пропускает существующий tag, генерирует release notes, выбирает Xcode, собирает universal app, пакует `.app.zip`, `.pkg`, `SHA256SUMS.txt`, создает annotated tag и публикует GitHub Release.

`feat:` и `fix:` попадают в отдельные секции release notes, остальные commits — в Changes.

## Версионирование

`VERSION` — основной источник версии. `Info.plist` использует `$(MARKETING_VERSION)`, поэтому окно настроек показывает Xcode marketing version.

Перед release обновите `VERSION` и `MARKETING_VERSION` в `Znak.xcodeproj/project.pbxproj`, затем commit и push в `main`.

## Заметки разработчика

- Держите `InputEngine` независимым от AppKit и реальных user defaults.
- Используйте dependency injection для preferences, dictionaries, phrases и learning stores.
- Тестируемое поведение клавиатуры сначала добавляйте в `InputControllerBehavior`.
- Порядок кандидатов — user-visible behavior, поэтому изменения требуют тестов.
- AppKit access должен быть на main thread/main actor.
- Не обучайте пунктуацию, фразы как слова, аномальный input и invalid text.
- При росте словарей следите за latency кандидатов.

## Troubleshooting

Если Znak не появляется в Input Sources, проверьте папку Input Methods, откройте app один раз и при необходимости перелогиньтесь.

Если вводятся только латинские буквы, вероятно включен English passthrough mode. Нажмите Shift один раз, чтобы вернуться в русский режим.

Удержание Shift не переключает английский режим намеренно: оно вводит русские заглавные буквы.

Если окно кандидатов появляется не там, host app мог вернуть неверный cursor rect; Znak использует fallback по visible screen frame.

Если GitHub Actions не публикует release, проверьте branch `main`, изменение `VERSION`, существование tag и permission `contents: write`.

## Contributing

Держите изменения узкими, добавляйте тесты для input behavior и ranking, сохраняйте нативный AppKit-подход, не добавляйте зависимости без необходимости, запускайте XCTest перед release и используйте commit prefixes `feat:` и `fix:`.
