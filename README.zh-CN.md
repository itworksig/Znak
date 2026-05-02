# Znak

[English](README.md) · [Русская версия](README.ru.md)

Znak 是一个原生 macOS Input MethodKit 输入法，用来在 QWERTY 键盘上快速输入俄语。它支持键位直映、词库候选、短语候选、模糊纠错、用户学习、候选排序偏好、自定义词库，以及原生 AppKit 设置窗口。

当前版本：`1.0.3`。

## 功能概览

- QWERTY 键位映射到俄语字符。
- 内置俄语词库和短语词库。
- 可选拉丁转写预测。
- 小拼写错误的模糊纠错候选。
- 用户学习：频率、上下文、最近使用、迁移、备份、修复、衰减。
- 候选排序偏好：优先常用词、优先键位直映、优先短语。
- 横向/纵向候选窗。
- 可配置候选数量和候选字号。
- 按住 Shift 输入大写俄语。
- 单击 Shift 切换英文直通模式。
- 可配置 Caps Lock 行为。
- 自定义词库导入/导出。
- 设置页显示当前版本，并检查 GitHub Releases 更新。
- GitHub Actions 构建 macOS 通用 `.app.zip` 和 `.pkg`。

## 仓库结构

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

## 架构说明

Znak 是一个小而原生的 AppKit/Input MethodKit 项目。没有包管理器，没有外部运行时，也没有服务端。输入法本体是一个安装到 macOS Input Methods 目录中的 AppKit bundle。

### 输入法外壳

`main.swift` 启动应用并注册 Input MethodKit server。`AppDelegate.swift` 负责菜单栏状态项、设置入口、退出菜单和当前输入模式标签。

常见安装路径：

- 当前用户：`~/Library/Input Methods/Znak.app`
- 系统范围：`/Library/Input Methods/Znak.app`

Release `.pkg` 会安装到 `/Library/Input Methods`。

### IMK 控制器

`InputController.swift` 是生产环境里的 `IMKInputController`，负责把 macOS 文本客户端、输入引擎和候选窗连接起来。

主要职责：

- 把键盘事件转成 composition 更新。
- 跟踪 raw input、marked text、候选、高亮位置和分页偏移。
- 提交选中候选或 fallback 文本。
- client 切换时隐藏旧候选窗。
- App 失焦或文本区域失效时清理 composition。
- 从 IMK client 获取光标矩形，失败时使用稳定 fallback。
- 按偏好保存全局或按 App 的输入模式状态。
- 推断 App context 时避免不安全 KVC 崩溃。

### 可测试行为核心

`InputControllerBehavior.swift` 把关键输入行为从真实 `IMKTextInput` 中抽离出来，使 XCTest 可以覆盖用户行为而不需要启动系统输入法会话。

覆盖内容包括空候选 fallback 提交、数字键选候选、翻页、按住 Shift 输入大写俄语、单击 Shift 切换英文、Caps Lock 行为、偏好变化刷新候选。

### 输入引擎

`InputEngine.swift` 是不依赖 AppKit 的核心。偏好、词库文本、短语文本和学习 store 都通过依赖注入传入，而不是直接读取用户默认值。这样测试稳定，也不会污染用户真实学习数据。

输入引擎负责键盘映射、词库解析与索引、短语索引、分层排序、模糊匹配、preview text、选择学习和学习词典持久化。

## 候选来源

`InputEngine.Candidate.Source` 表示候选来源：

- `builtin`：内置词库。
- `custom`：用户自定义词库。
- `learned`：学习词。
- `phrase`：短语候选。
- `fuzzy`：纠错候选。
- `mapped`：键位直映 fallback。

这些来源也用于候选窗 debug 标签。

## 候选排序

候选排序被明确拆成层级，避免 `ghb` 这种输入的结果不可控。到底优先出现 `привет`、`приказ`，还是直映的 `при`，由排序偏好决定。

### `commonWords`

默认日常输入模式：

1. 内置词库、自定义词库、学习词里的精确候选。
2. 在词库层内部叠加用户学习和前词上下文加权。
3. 短语候选。
4. 模糊纠错候选。
5. 只有没有更强候选时才加入键位直映 fallback。

### `directMapping`

把键位直映结果放在最前。适合希望 Znak 更像严格俄语键盘布局、候选只是辅助的用户。

### `phrases`

把短语候选放在词库补全之前。适合固定表达较多的输入场景。

## 学习系统

`UserLexiconStore` 遵守 `InputLearningStore`，以 JSON 形式存储在 App Support 目录。它记录单词频率、input-to-word 分数、前词 bigram、短语分数、最近选择、schema version 和 selection sequence。

当前 schema version 是 `4`。

学习系统会避免学习纯标点、短语、异常输入和非法文本。它会定期衰减旧频率，避免早期误学永久压过新习惯。写入前会备份，加载时会尽量修复和迁移旧数据。

在设置里清空学习后，活跃输入引擎会立即 reload。

## 偏好系统

偏好结构是 `Preferences.swift` 里的 `InputPreferences`，持久化由 `PreferencesStore` 负责。

重要字段：

- `latinPredictionEnabled`：是否启用拉丁转写预测。
- `customDictionaryText`：自定义词库文本。
- `preeditStyle`：预编辑文本样式。
- `themePreset`：候选窗主题。
- `maxCandidateCount`：候选数量上限。
- `candidateRankingPreference`：候选排序偏好。
- `candidateLayout`：横向/纵向候选窗。
- `candidateFontSize`：候选字号。
- `capsLockBehavior`：Caps Lock 行为。
- `persistInputModeState`：是否保存全局/按 App 输入模式。
- `showCandidateSourceDebug`：是否显示候选来源/debug 信息。

`PreferencesWindowController.swift` 使用原生 AppKit 控件实现设置窗口。

## 输入模式

Znak 有俄语模式和英文直通模式。俄语模式会映射按键并显示候选；英文模式直接传递拉丁字符。

按住 Shift 不会切换英文，而是输入大写俄语。单独按下并释放 Shift 才会切换英文直通模式。

Caps Lock 可配置为直接传递、切换英文模式或输入大写俄语。

## 候选窗

`CandidateWindowController.swift` 使用 `NSPanel` 和 AppKit 自绘实现候选窗。

它支持主题、横向/纵向布局、字号、候选来源标签、输入模式 badge、分页 badge、toast、稳定 fallback 定位、多显示器和全屏 App。

所有 AppKit 窗口和视图访问都要保持在主线程/main actor，尤其 Xcode 16 Release 构建会更严格检查 AppKit 隔离。

## 词库

`Znak/RussianDictionary.txt` 是内置词库，词条可以带可选频率。

`Znak/RussianPhrases.txt` 是短语词库，按前缀和上下文索引，也可以作为全局短语候选。

自定义词库存储在偏好里，可以在设置页编辑、导入和导出，不会写进 app bundle。

## 检查更新

设置页会请求 GitHub 最新 Release：

```text
https://api.github.com/repos/itworksig/Znak/releases/latest
```

它比较本地 `CFBundleShortVersionString` 和最新 release tag。已经是最新版时显示中英俄三语提示；有新版本时下载 `.pkg` 到 `~/Downloads` 并自动打开。

Release 文件命名约定：

```text
Znak-<version>-macos-universal.pkg
Znak-<version>-macos-universal.app.zip
SHA256SUMS.txt
```

## 开发环境

开发需要 macOS。Release 构建推荐 Xcode 16。Xcode 15.4 在显式传入 `SWIFT_VERSION=5.0` 时也可以构建。当前 release deployment target 是 macOS 13 或更新。

## 构建

Debug 构建：

```bash
xcodebuild \
  -project Znak.xcodeproj \
  -scheme Znak \
  -configuration Debug \
  -derivedDataPath /tmp/ZnakDerivedData \
  build
```

Release 通用构建：

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

## 本地安装

构建到 `/tmp/ZnakDerivedData` 后：

```bash
killall Znak 2>/dev/null || true
sleep 0.8
rm -rf "$HOME/Library/Input Methods/Znak.app"
cp -R "/tmp/ZnakDerivedData/Build/Products/Debug/Znak.app" "$HOME/Library/Input Methods/Znak.app"
open "$HOME/Library/Input Methods/Znak.app"
```

然后在系统设置 > 键盘 > 输入源里启用 Znak。

## 测试

运行全部测试：

```bash
xcodebuild test \
  -project Znak.xcodeproj \
  -scheme Znak \
  -derivedDataPath /tmp/ZnakDerivedDataTests
```

测试包含：

- `InputEngineTests`：映射、词库候选、转写、模糊匹配、短语、排序偏好、偏好解码、学习词典迁移、学习过滤。
- `InputControllerBehaviorTests`：不依赖真实 IMK client 的行为测试。
- `InputEnginePerformanceTests`：增量候选、fuzzy pool、短语查找、大规模学习词典性能。

## Release 流程

`.github/workflows/release.yml` 会在 push 到 `main` 且修改 `VERSION` 或 workflow 文件时触发，也可以手动触发。

流程：读取 `VERSION`，生成 `v<version>`，tag 已存在则跳过，从 commit 生成 release notes，选择 Xcode，构建 universal app，打包 `.app.zip`、`.pkg`、`SHA256SUMS.txt`，创建 annotated tag，发布 GitHub Release。

`feat:` 和 `fix:` commit 会进入对应 release note 分区，其他提交进入 Changes。

## 版本管理

`VERSION` 是 release 版本来源。`Info.plist` 使用 `$(MARKETING_VERSION)`，所以设置页显示 Xcode marketing version。

发布前需要更新 `VERSION` 和 `Znak.xcodeproj/project.pbxproj` 中的 `MARKETING_VERSION`，提交并 push 到 `main`。

## 开发建议

- 保持 `InputEngine` 和 AppKit、真实用户默认值解耦。
- 新输入行为优先通过依赖注入实现。
- 可测试的键盘行为先放进 `InputControllerBehavior`。
- 候选排序是用户可见行为，改动必须补测试。
- AppKit 访问保持在主线程/main actor。
- 不学习标点、短语、异常输入和非法文本。
- 词库或学习数据变大时关注候选延迟。

## 排障

输入法不出现时，确认 `Znak.app` 在 Input Methods 目录、复制后打开过一次，并在系统设置里添加。必要时注销再登录。

只能输入拉丁字母时，通常是英文直通模式，单击 Shift 切回俄语。

按住 Shift 不切换英文是设计如此：按住 Shift 输入大写俄语，单击 Shift 才切换英文。

候选窗位置不对时，可能是宿主 App 返回了无效光标矩形，Znak 会使用屏幕 visible frame fallback。

GitHub Actions 不发布时，检查是否 push 到 `main`、`VERSION` 是否变化、tag 是否已存在、workflow 是否有 `contents: write` 权限。

## 贡献

保持改动范围清晰，为输入行为和排序变化补测试，保持原生 AppKit 风格，不轻易引入外部依赖，release 前运行完整 XCTest，并使用 `feat:`、`fix:` 等清晰 commit 前缀。
