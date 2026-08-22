# ドライブモード実装計画（Drive Mode MVP）— 実行指示書

本書は [ux-design.md §10](./ux-design.md)（UX 正本）を実装に写像する**実行計画**である。実行担当はコード・テスト・`Resources/Localizable.xcstrings`・`App/project.yml`、および変更に対応する docs の同期を編集してよい。CI 設定（`.github/workflows/`）の変更は不要（新規テストターゲットは `App/project.yml` の scheme 追加だけで `ios-macos` に取り込まれる）。

> **状態: 実装済み（D1〜D8）。** フェーズ位置づけは roadmap Phase 2 の前倒し最優先項目。実機 / 車載 Bluetooth の DoD は未確認（本計画 §4.3）。

関連文書: [ux-design.md §10](./ux-design.md)（UX 正本）/ [architecture.md](./architecture.md)(設計正本) / [roadmap.md](./roadmap.md)（スコープ正本）/ [quality-pass-plan.md](./quality-pass-plan.md)（直近の品質パス。テストターゲット追加・DI シームの前例）/ [development-workflow.md](./development-workflow.md)（ブランチ・コミット規約）。

## 0. 前提と原則

- **ベースライン**: core（`Packages/SnapSpeakCore`、Linux `swift test`）153 テスト green / iOS hostless（macOS CI）green / SwiftLint strict green。**各コミットでこの green を維持する。**
- **Linux VM の制約**: `Packages/SnapSpeakiOS` はローカルでコンパイルできない。iOS 側を触るコミットは毎回 `ios-macos` CI で確認する（CI をコンパイラとして使う既存運用。AGENTS.md）。**ロジックは可能な限り core（DriveKit）に寄せ、Linux でテストする。**
- **不変条件**（roadmap「フェーズ横断の不変条件」）: TCA 禁止・core は Apple フレームワーク import 禁止・UI 文字列は String Catalog・`ReviewEvent` 追記型・`AppleLanguages` 書換え禁止。ドライブモード固有の追加原則は ux-design §10.1（D1〜D5）。
- **マイク・録音・ASR はドライブモードで一切使わない。** 権限も要求しない。完了は未採点 `LessonAttempt` のみ（`ReviewEvent` は書かない）。
- **シード音声はダミーバイト**（checksum 整合用。実再生不可 — AGENTS.md）。したがって **TTS フォールバック（`AVSpeechSynthesizer`）が初期リリースの実質的な正本経路**である。ファイル再生経路は実装するが、実機での聴感確認は本番収録音声への差し替え後になる。TTS 経路を「例外処理」ではなく一級の経路として実装・テストする。
- **既存資産の再利用（二重実装しない）**: プラン生成は `HabitKit.SessionPlanner`（既存）、完了の習慣評価は `PersistenceActor.appendAttemptEvaluatingHabit`（既存）、コンテンツ解決は `CourseStore` / `StoredCourse`（既存）。ドライブモードが新規に持つのは「音声スクリプト生成」「音声シーケンス実行」「専用画面」だけである。
- **docs 同期規約**: 公開 API・UI 文言・仕様を変えるコミットは、同一コミットで該当 docs を更新する。本計画では特に: architecture §2.1（モジュール表への `DriveKit` / `DriveModeFeature` 追加と依存図）、architecture §7.4 付近（Attempt payload の形式表 — §2.3）、ux-design §10（文言・数値の確定反映）、roadmap Phase 2（チェック消し込み）。
- **AudioEngineActor は変更しない**: ドライブ用シーケンサは独立させる（§2.1）。同時アクティブにしない不変条件はアプリ側で守る（§2.5）。

---

## 1. SnapSpeakCore — 新モジュール `DriveKit`

音声スクリプト生成（純関数）と進行カーソル（純状態機械）を core に置き、Linux で網羅テストする。iOS 側は「フェーズを 1 個ずつ実行する」薄い実行係になる。

### 1.1 Package.swift 変更

```swift
// products に追加
.library(name: "DriveKit", targets: ["DriveKit"]),
// targets に追加
.target(name: "DriveKit", dependencies: ["SRSKit"], swiftSettings: swift6),
.testTarget(name: "DriveKitTests", dependencies: ["DriveKit", "SRSKit"], swiftSettings: swift6),
```

依存は `SRSKit` のみ（`Skill` 型のため。`HabitKit` と同じ最小依存方針）。言語は正規化済み BCP-47 の生 `String` タグで受ける（`LanguageKit` 依存を持たない。正規化は上流 = ContentCore デコーダが保証済み）。

### 1.2 型定義（公開 API スケッチ）

```swift
import SRSKit

/// スクリプト生成の入力 1 件（iOS 側で SessionPlan + StoredCourse から写像する。§2.2）。
public struct DriveItem: Sendable, Equatable {
    public enum Origin: String, Sendable { case due, new, repeatFill }
    public var courseId: String
    public var itemId: String
    public var skill: Skill               // .shadowing | .composition
    public var origin: Origin
    public var l1Text: String?            // composition の出題（composition では必須。欠落は builder が除外）
    public var l2Text: String             // composition: acceptable 先頭 / shadowing: passage.text
    public var l1LanguageTag: String      // 例 "ja"
    public var l2LanguageTag: String      // 例 "en"
    public var audioRelativePath: String? // お手本音声（コースディレクトリ相対）
    public var audioDurationMs: Int?      // コンテンツ JSON の durationMs
}

/// タイミング定数（ux-design §10.4 の初期仮値。テストで注入・将来校正）。
public struct DriveTimingPolicy: Sendable, Equatable {
    public var speakPauseFactor: Double      // 1.6
    public var speakPauseClampMs: ClosedRange<Int>  // 3_000...12_000
    public var repeatPauseFactor: Double     // 1.0
    public var repeatPauseClampMs: ClosedRange<Int> // 2_000...8_000
    public var trackGapMs: Int               // 800
    public var itemGapMs: Int                // 1_200
    public var ttsBaseMs: Int                // 500（TTS 推定の定数項）
    public var ttsMsPerCharL1: Int           // 90（ja 初期仮値）
    public var ttsMsPerCharL2: Int           // 60（en 初期仮値）
    public var announceIntroMs: Int          // 8_000
    public var announceSectionMs: Int        // 2_500
    public var announceOutroMs: Int          // 5_000
    public var maxUnrolledItemPasses: Int    // 300（反復充填の暴走防止）
    public static let standard: DriveTimingPolicy
}

public struct DriveScriptSettings: Sendable, Equatable {
    public enum SessionLength: Int, Sendable, CaseIterable {
        case minutes5 = 5, minutes10 = 10, minutes20 = 20, endless = 0
    }
    public var sessionLength: SessionLength   // 既定 .minutes10
    public var pauseMultiplier: Double        // 0.8 / 1.0 / 1.3（Settings のプリセット写像）
    public var shadowingRepeats: Int          // 1...3 にクランプ。既定 2
    public var timing: DriveTimingPolicy      // 既定 .standard
}

/// アナウンスは意味だけを持つ。文言は iOS 側が String Catalog から解決して TTS に渡す
/// （core に日本語リテラルを置かない）。
public enum DriveAnnouncement: Sendable, Equatable {
    case sessionIntro(dueCount: Int, newCount: Int, isRepeatFill: Bool, isEndless: Bool)
    case newLessonSection
    case sessionOutro   // 完了数は実行時にしか分からないため実行側が整形する
}

public enum DrivePhaseKind: String, Sendable {
    case sessionIntro, sectionAnnounce, promptL1, speakPause, revealL2,
         repeatPause, shadowTrack, trackGap, itemGap, sessionOutro
}

public enum DrivePhaseAudio: Sendable, Equatable {
    case announcement(DriveAnnouncement)
    case contentTTS(text: String, languageTag: String)
    case file(courseId: String, relativePath: String,
              fallbackText: String, fallbackLanguageTag: String) // 再生失敗時の TTS 代替を同梱
    case silence
}

/// Item の 1 周（pass）を識別する参照。Attempt 追記・ノート表示・カーソル出力で使う。
public struct DriveItemRef: Sendable, Equatable, Hashable {
    public var courseId: String
    public var itemId: String
    public var skill: Skill
    public var passIndex: Int   // 0 始まり。反復充填で増える
}

public struct DrivePhase: Sendable, Equatable {
    public var kind: DrivePhaseKind
    public var audio: DrivePhaseAudio
    public var estimatedDurationMs: Int
    public var item: DriveItemRef?   // アナウンス系は nil
}

public struct DriveScript: Sendable, Equatable {
    public var phases: [DrivePhase]
    public var plannedTotalMs: Int
    public var itemPassCount: Int          // 完走した場合の完了数（= itemCompleted の総数）
    public var loops: Bool                 // endless のとき true（phases は 1 周分のみ）
    public var omittedItemIds: [String]    // 生成不能で落とした Item（例: composition の l1Text 欠落）
}

public enum DriveScriptBuilder {
    /// 決定的な純関数。乱数なし。入力順を保存する（items は SessionPlanner の順序で渡すこと）。
    public static func build(items: [DriveItem], settings: DriveScriptSettings) -> DriveScript
}
```

### 1.3 スクリプト生成規則（`DriveScriptBuilder`）

1. **検証**: `skill == .composition` かつ `l1Text == nil` の Item は落とし `omittedItemIds` に記録する（フェーズを出さない）。`l2Text` が空の Item も同様。
2. **Item → フェーズ列**（ux-design §10.4 の表と 1:1）:
   - composition: `promptL1(contentTTS l1)` → `speakPause(silence)` → `revealL2(file or contentTTS l2)` → `repeatPause(silence)` → `itemGap(silence)`
   - shadowing: `shadowTrack(file or contentTTS l2)` × `shadowingRepeats`（間に `trackGap`）→ `itemGap`
   - `audioRelativePath` があるフェーズは `.file(...)`（`fallbackText` = `l2Text` を同梱）、なければ `.contentTTS(l2Text)`。
3. **長さ計算**:
   - 正解長 `answerMs` = `audioDurationMs` ?? TTS 推定（`ttsBaseMs + msPerChar × 文字数`。L1 / L2 で係数が異なる）。
   - `speakPauseMs = clamp(round(answerMs × speakPauseFactor × pauseMultiplier), speakPauseClampMs)`
   - `repeatPauseMs = clamp(round(answerMs × repeatPauseFactor × pauseMultiplier), repeatPauseClampMs)`
4. **アナウンス**: 先頭に `sessionIntro`（dueCount / newCount は `origin` の集計。repeatFill のみなら `isRepeatFill: true`）。`origin` が due → new に切り替わる位置に `sectionAnnounce(newLessonSection)` を 1 回だけ挿入。末尾（endless 以外）に `sessionOutro`。
5. **切り詰めと反復充填**（endless 以外）: 予算 = `sessionLength.rawValue × 60_000`。アナウンス推定を含めて Item 単位で積算し、**予算を超える直前で切る**。最低 1 Item は保証（先頭 Item が単独で予算超過でも含める）。全 Item を含めても予算に満たない場合は同じ Item 列を `passIndex` を増やして繰り返し充填する（`maxUnrolledItemPasses` で上限）。2 周目以降の Item は `origin` を保存したまま `passIndex` のみ増える。`sectionAnnounce` は 1 周目のみ。
6. **endless**: 1 周分のみ生成し `loops = true`。`sessionOutro` は入れない（手動停止時にアナウンスしない — ux-design §10.3）。カーソルが末尾で先頭 Item（`sessionIntro` の次）へ巻き戻る。
7. **決定性**: 同一入力 → 同一出力。並べ替え・シャッフルをしない（順序は入力 = `SessionPlanner` 順）。

### 1.4 進行カーソル（`DriveCursor`）

シーケンサの進行判断をすべて純状態機械に寄せ、Linux でテストする。

```swift
public struct DriveCursor: Sendable, Equatable {
    public enum Event: Sendable, Equatable {
        case phaseFinished        // 実行側: 現フェーズの再生 / 無音が終わった
        case skipToNextItem       // リモコン nextTrack / 実行側の Item スキップ（TTS ボイス不能など）
        case previousPressed      // リモコン previousTrack
        case pause
        case resume
        case stop                 // 手動終了
    }
    public enum Output: Sendable, Equatable {
        case play(phaseIndex: Int)                 // 実行側は script.phases[i] を再生する
        case itemCompleted(DriveItemRef)           // Item の最終フェーズが自然終了した
        case finished(endedByUser: Bool)           // 完走 false / 手動停止 true
    }
    public init(script: DriveScript)
    public private(set) var isPaused: Bool
    public private(set) var completedPassCount: Int
    public mutating func start() -> [Output]
    public mutating func apply(_ event: Event) -> [Output]
}
```

意味論（テストで固定する）:

| イベント | 規則 |
|----------|------|
| `start()` | 先頭フェーズの `play` を返す |
| `phaseFinished` | 次フェーズの `play`。Item の最終フェーズ（次フェーズが別 Item またはアナウンスまたは末尾）なら `itemCompleted` を先に出す。末尾なら `finished(endedByUser: false)`（`loops` なら先頭 Item へ巻き戻り、`passIndex` を加算した `play`） |
| `pause` | 以後 `phaseFinished` を無視。出力なし |
| `resume` | **現在 Item の先頭フェーズ**から `play`（フェーズ途中復帰はしない — ux-design §10.6）。アナウンス中の一時停止はそのアナウンスの頭から |
| `skipToNextItem` | 次 Item の先頭へ `play`。現在 Item の `itemCompleted` は出さない。最終 Item でのスキップは `finished(endedByUser: false)`（endless は次周へ） |
| `previousPressed` | 現在 Item の先頭へ。現在 Item のフェーズが 1 つも完了していなければ前の Item の先頭へ（先頭 Item では自 Item の頭に留まる） |
| `stop` | `finished(endedByUser: true)`。以後すべてのイベントを無視 |
| 完了の一回性 | 同一 `DriveItemRef`（passIndex 込み）の `itemCompleted` は最大 1 回 |

### 1.5 Linux テスト項目（`DriveKitTests`。境界条件の列挙）

**Builder**:

| # | ケース |
|---|--------|
| B1 | 空 items → phases 空・`itemPassCount == 0`・loops false（開始可否の判断は呼び出し側） |
| B2 | composition 1 件の標準フェーズ列（kind / audio / item 参照の完全一致。intro と outro を含む） |
| B3 | shadowing repeats = 1 / 2 / 3 のフェーズ数と trackGap の位置 |
| B4 | `audioDurationMs` あり → `answerMs` に採用 / なし → TTS 推定式（L1 / L2 係数の別） |
| B5 | speakPause のクランプ下限（極端に短い正解）と上限（長い正解）、`pauseMultiplier` 0.8 / 1.3 の反映 |
| B6 | 切り詰め: 予算ちょうど / 1ms 不足で次 Item が落ちる / 先頭 Item が予算超過でも 1 件は残る |
| B7 | 反復充填: 合計が予算未満 → 2 周目が入り `passIndex` が増える。`sectionAnnounce` は 1 周目のみ。`maxUnrolledItemPasses` の上限 |
| B8 | endless: `loops == true`・1 周のみ・outro なし |
| B9 | composition の `l1Text` 欠落 / `l2Text` 空 → `omittedItemIds` に入り phases に現れない |
| B10 | due → new の境界に `sectionAnnounce` が 1 回だけ。due のみ / new のみ / repeatFill のみでの intro パラメータ |
| B11 | 決定性: 同一入力 2 回で `DriveScript` が等価 |

**Cursor**:

| # | ケース |
|---|--------|
| C1 | 正常完走: `itemCompleted` が `itemPassCount` 回・順序どおり・最後に `finished(endedByUser: false)` |
| C2 | `skipToNextItem` は `itemCompleted` を出さない。スキップ後の完走で完了数が 1 少ない |
| C3 | `previousPressed`: Item 途中 → 自 Item の頭 / Item 先頭 → 前 Item の頭 / 先頭 Item では自 Item の頭 |
| C4 | `pause` 中の `phaseFinished` 無視 → `resume` で現在 Item の頭から |
| C5 | `stop` → `finished(endedByUser: true)`、以後のイベント無視・出力なし |
| C6 | endless: 末尾到達で先頭 Item へ巻き戻り `passIndex` 加算・`completedPassCount` 累積 |
| C7 | 完了の一回性: resume による Item 頭からのやり直しで同一 pass の `itemCompleted` が重複しない |

---

## 2. SnapSpeakiOS

### 2.1 AudioEngine 拡張（`Packages/SnapSpeakiOS/Sources/AudioEngine/`）

既存 `AudioEngineActor` は**変更しない**（割り込みポリシーが異なるため。既存は interruptionEnded で teardown、ドライブは自動再開）。新規に以下を追加する。

| 追加物 | 内容 |
|--------|------|
| `SpeechSynthesizing`（protocol） | `func speak(text: String, languageTag: String) async throws` / `func stopSpeaking()`。Sendable。テスト用フェイクのシーム |
| `SpeechSynthesisClient` | `AVSpeechSynthesizer` ラッパ（`AVSpeechSynthesizerDelegate.didFinish` を continuation で async 化）。ボイスは `AVSpeechSynthesisVoice(language:)` で解決し、解決不能は `SpeechSynthesisError.voiceUnavailable` を投げる（シーケンサが Item スキップに写像）。レートは既定値。キャンセル対応（`stopSpeaking()` → continuation resume） |
| `PhaseFilePlaying`（protocol）+ `SequenceFilePlayer` | 単発ファイル再生の async 版（`play(url:) async throws`、完了で return、`stop()`）。実装は `AVAudioPlayerNode` + 完了コールバック（`.dataPlayedBack`）。既存 `PlayerGraph` とは独立の小さなグラフ（速度変更・録音タップ不要のため `AVAudioUnitTimePitch` なし）。`AVAudioFile` オープン失敗（**ダミーバイトを含む**）は throw し、シーケンサが TTS フォールバックする |
| `DriveSequencer`（actor） | `DriveScript` を実行する。内部に `DriveCursor` を保持し、`play(phaseIndex:)` 出力を「file → `PhaseFilePlaying`（失敗時は同梱 fallbackText で `SpeechSynthesizing`）/ contentTTS・announcement → `SpeechSynthesizing` / silence → `Task.sleep`（クロック注入可）」に写像する。公開 API: `start(script:announcementTexts:)` / `pause()` / `resume()` / `skipForward()` / `skipBackward()` / `stop()`、イベントは `AsyncStream<DriveSequencerEvent>`（`phaseChanged(kind:itemRef:)` / `itemCompleted(DriveItemRef, usedTTSFallback: Bool, elapsedMs: Int)` / `paused(reason:)` / `resumed` / `finished(endedByUser:completedCount:)`） |
| 割り込み処理 | `DriveSequencer` が既存 `RecoveryObserver` を購読し、ドライブ用ポリシーで処理する: interruptionBegan → `pause(reason: .interruption)` / interruptionEnded(shouldResume) → **自動 `resume()`**（shouldResume なしは pause 維持）/ routeChange（oldDeviceUnavailable）→ pause 維持（自動再開しない）/ mediaServicesReset → グラフ・シンセ再構築して pause 維持（ux-design §10.6 と 1:1） |
| セッション構成 | `AudioSessionConfigurator` の既存 `activatePreview()`（`.playback + .spokenAudio`）を再利用する。録音カテゴリは使わない |
| `DriveRemoteCommandBridge`（@MainActor） | `MPRemoteCommandCenter`（play / pause / togglePlayPause / nextTrack / previousTrack を有効化、seek / skipInterval / changePlaybackRate を無効化）→ `DriveSequencer` へ転送。`MPNowPlayingInfoCenter` を `phaseChanged` / pause / resume で更新（タイトル・コース名 + 進捗・playbackState のみ。**学習テキストは載せない** — ux-design §10.7）。`import MediaPlayer` は本ファイルに閉じる。ロジックを持たない薄い橋（hostless テスト対象外） |

アナウンス文言の解決: `DriveAnnouncement` → 文字列は **AppFeature / DriveModeFeature 側**で `String(localized:)` して `start(script:announcementTexts:)` に辞書で渡す（AudioEngine に String Catalog 依存を持ち込まない。`sessionOutro` の完了数はシーケンサが `finished` 直前に実測完了数で整形できるようクロージャ `(Int) -> String` で渡す）。

### 2.2 新モジュール `DriveModeFeature`（`Packages/SnapSpeakiOS/Sources/DriveModeFeature/`）

`Packages/SnapSpeakiOS/Package.swift` に target / product を追加。依存: `AudioEngine` / `ContentKit` / `Persistence` / `DesignSystem` / `Analytics` + core の `DriveKit` / `HabitKit` / `SRSKit` / `ContentCore`。**`ReviewFeature` は import しない**（Feature 間 import 禁止。プランは AppFeature が `TodayPlanService` で作って渡す — §2.5）。

| ファイル | 内容 |
|----------|------|
| `DrivePlanResolver.swift` | `static func resolve(plan: SessionPlan, courses: [StoredCourse]) -> [DriveItem]` — `ReviewSessionViewModel.resolveEntries` と同じ規則（due → new、courseId + itemId で解決、重複除外、欠損スキップ）で `DriveItem` に写像する純関数。composition は `l1Text = sentencePair.l1`、`l2Text = acceptable.first`、shadowing は `l2Text = passage.text`。言語タグは `stored.course.languagePair` から。加えて `static func repeatFillItems(courses:limit:) -> [DriveItem]` — プラン空のときのカタログ順反復素材（ux-design §10.3） |
| `DriveSessionViewModel.swift` | `@MainActor`。状態 `idle / starting / running(phaseKind:itemIndex:paused:) / finished(note:)`。`start(settings:plan:courses:)` → resolver → `DriveScriptBuilder.build` → シーケンサ開始 → イベント購読。`itemCompleted` ごとに `DriveAttemptRecorder.record`（下記）とノート行の蓄積。`finished` で `drive_session_completed` を track しノート状態へ。シーケンサはプロトコル（`DriveSequencing`）越しに注入（hostless テスト用フェイク） |
| `DriveAttemptRecorder.swift` | `itemCompleted` → `appendAttemptEvaluatingHabit(LessonAttemptWrite(...))`。skill は本来の値、`durationMs` = シーケンサ実測 `elapsedMs`、payload は §2.3。返り値 `AttemptHabitResult` から `streak_day_recorded` / `goal_met` を track（`LiveShadowingUseCase.trackHabit` と同型の 8 行。共有化は Feature 間 import になるため**意図的に重複**させ、コメントで相互参照する） |
| `DriveStartView.swift` | ux-design §10.5.1。プラン内訳・長さ 4 択（保存値を読み書き）・巨大開始ボタン・安全注意。プラン読み込み失敗時は再試行（`home.today.load_failed` 再利用） |
| `DriveGlanceView.swift` | ux-design §10.5.2。状態語（きく / はなす / こたえ / 一時停止中）・進捗・下半分の一時停止 ⇄ 再開・左上終了。学習テキストを表示しない |
| `DriveNoteView.swift` | ux-design §10.5.3。完了 Item の L1 / L2 一覧（反復は 1 行に回数）・聞き直し（`SpeechSynthesizing` / `PhaseFilePlaying` で 1 回再生）・「通常レッスンで採点つきで練習する」（クロージャで AppFeature に委譲）・閉じる。表示時に `drive_note_opened` |

### 2.3 Persistence（`Packages/SnapSpeakiOS/Sources/Persistence/`）

**UserSettings フィールド追加**（`@Model` と `UserSettingsDTO` と `phase1Default`）:

| フィールド | 型 | 既定 | 意味 |
|-----------|----|------|------|
| `driveSessionMinutes` | `Int` | `10` | セッション長（分）。`0` = エンドレス（`DriveScriptSettings.SessionLength` の rawValue と 1:1） |
| `drivePausePreset` | `String` | `"standard"` | `short` / `standard` / `long` → 0.8 / 1.0 / 1.3 |
| `driveShadowingRepeats` | `Int` | `2` | 1...3 |

ストアは未配布のため `SnapSpeakSchemaV1` への直接追加でよい（architecture §7.4 の規定内。`SnapSpeakMigrationPlan` のステージは増やさない）。**配布後に本計画を実行する場合は V2 + マイグレーションステージ追加に切り替えること。**

**Attempt payload**（ドライブ文脈の判別。architecture §7.4 の「payloadJSON + payloadSchemaVersion」規約に従い、外側バージョンは skill ごとの**形状 ID** として扱う）:

```swift
// DriveModeFeature 内に定義
struct DriveAttemptPayload: Codable, Sendable {
    var payloadSchemaVersion: Int   // 外側と同値（shadowing: 2 / composition: 3）
    var context: String             // "drive"（判別子）
    var passIndex: Int              // 反復充填の周回
    var usedTTSFallback: Bool       // お手本がファイルでなく TTS で提示された
    var speakPauseMs: Int?          // composition のみ
    var repeats: Int?               // shadowing のみ
}
```

| skill | 外側 payloadSchemaVersion | 形状 |
|-------|---------------------------|------|
| shadowing | 1 | `ShadowingScore` または `{}`（通常レッスン。既存） |
| shadowing | **2** | `DriveAttemptPayload`（新規） |
| composition | 1 | 旧形式（`v0.1.0` タグ。decode 互換のみ） |
| composition | 2 | `CompositionAttemptPayload`（既存） |
| composition | **3** | `DriveAttemptPayload`（新規） |

この表を **architecture §7.4 に同一コミットで追記**する。`ReviewEvent` は書かない（品質なし）。`foldSRSCard` も呼ばない。

**ドライブノートは永続化しない**（セッション終了時の in-memory 状態から表示。完了の事実は Attempt に残っており、将来のダッシュボードは payload の `context == "drive"` で判別できる）。Persistence の新 API は不要。

### 2.4 AnalyticsCore（`Packages/SnapSpeakCore/Sources/AnalyticsCore/AnalyticsEvent.swift`）

```swift
case driveSessionStarted(dueCount: Int, newCount: Int, lengthCode: String)  // "5" | "10" | "20" | "endless"
case driveSessionCompleted(completedCount: Int, durationBand: String,
                           endReason: String,        // "finished" | "stopped"
                           usedTTSFallback: Bool)
case driveNoteOpened(completedCount: Int)
```

ux-design §9 の表と 1:1。生テキスト・座標・速度など運転関連の個人データは**送らない**（走行の有無すら推定できる位置情報系は一切収集しない）。

### 2.5 AppFeature 統合

| 変更 | 内容 |
|------|------|
| `HomeView` | 「今日の学習」カードの下にドライブモードカード（`home.drive.*`）。「すぐ始める」= 保存済み設定で即セッション開始（ワンタップ）/ カード本体タップ = `DriveStartView` へ |
| `RootView` | ドライブセッションは `fullScreenCover`（誤ジェスチャ防止。既存レッスンプレイヤーと同方針）。開始時に `await dependencies.audio.stop()` を呼び、`AudioEngineActor` と `DriveSequencer` を同時アクティブにしない（アプリ不変条件。逆方向 — 通常レッスン開始時 — はドライブが fullScreenCover 中のため到達不能） |
| プラン供給 | 開始直前に `TodayPlanService.makeToday` で**再生成**し（`regeneratePlanThenStart` と同方針）、`snapshot.plan` + `courseStore.allCourses()` を `DriveModeFeature` に渡す（`DriveModeFeature` → `ReviewFeature` の import を作らない） |
| `AppDependencies` | `speechSynthesis: SpeechSynthesisClient`・`driveSequencer: DriveSequencer`・`driveRemoteBridge: DriveRemoteCommandBridge` を追加し `live(resourceBundle:)` で組み立てる |
| 通常レッスンへの導線 | ドライブノートの「通常レッスンで採点つきで練習する」→ 既存 `StandaloneLessonHost`（当該 courseId / lessonId / itemId） |

### 2.6 String Catalog 追加キー一覧（`Resources/Localizable.xcstrings`、ja 値）

命名は ux-design §8。TTS アナウンス（`drive.announce.*`）と NowPlaying タイトルは `Text()` を通らないため SwiftLint カスタムルールに掛からない — `String(localized:)` 経由をレビューで担保する（`ReminderContent` と同じ扱い。ux-design §8 に注記済み）。

| キー | ja 値 |
|------|-------|
| `home.drive.title` | ドライブモード |
| `home.drive.subtitle` | 運転中は音声だけで練習 |
| `home.drive.quick_start` | すぐ始める |
| `drive.start.title` | ドライブモード |
| `drive.start.plan_summary` | 復習 %1$lld 問 ・ 新しいレッスン %2$lld 問 |
| `drive.start.plan_repeat_fill` | 今日の分は完了しています。これまでの表現を反復します |
| `drive.start.length_5` | 5分 |
| `drive.start.length_10` | 10分 |
| `drive.start.length_20` | 20分 |
| `drive.start.length_endless` | エンドレス |
| `drive.start.start` | 開始する |
| `drive.start.safety_note` | 走行中は画面を操作しないでください。開始後は音声だけで進みます。 |
| `drive.glance.listening` | きく |
| `drive.glance.speak` | はなす |
| `drive.glance.answer` | こたえ |
| `drive.glance.paused` | 一時停止中 |
| `drive.glance.progress` | %1$lld / %2$lld |
| `drive.glance.pause` | 一時停止 |
| `drive.glance.resume` | 再開 |
| `drive.glance.stop` | 終了 |
| `drive.announce.intro` | ドライブモードを開始します。復習 %1$lld 問と新しい問題 %2$lld 問を練習します。音声のあとに続けて話してください。 |
| `drive.announce.intro_repeat_fill` | ドライブモードを開始します。これまでに練習した表現を反復します。音声のあとに続けて話してください。 |
| `drive.announce.intro_endless` | ドライブモードを開始します。停止するまで練習を続けます。音声のあとに続けて話してください。 |
| `drive.announce.new_section` | ここからは新しいレッスンです。 |
| `drive.announce.outro` | セッション終了です。%lld 問練習しました。おつかれさまでした。 |
| `drive.note.title` | ドライブノート |
| `drive.note.summary` | %lld 問練習しました |
| `drive.note.repeat_count` | %lld 回反復 |
| `drive.note.replay` | 聞き直す |
| `drive.note.open_lesson` | 通常レッスンで採点つきで練習する |
| `drive.note.review_hint` | ドライブでは採点しないため、復習カードはそのまま残っています。 |
| `drive.note.missing` | 再生できなかった教材があります |
| `drive.note.close` | 閉じる |
| `drive.nowplaying.title` | ドライブモード |
| `settings.section_drive` | ドライブモード |
| `settings.drive_length` | セッションの長さ |
| `settings.drive_pause` | 発話ポーズ |
| `settings.drive_pause_short` | みじかめ |
| `settings.drive_pause_standard` | ふつう |
| `settings.drive_pause_long` | ながめ |
| `settings.drive_repeats` | シャドーイングの反復回数 |

（`drive.start.length_*` は Settings のセッション長メニューでも再利用する。）

---

## 3. `App/project.yml`・Info.plist・SwiftLint への影響

| 対象 | 変更 |
|------|------|
| Info.plist（`App/project.yml` の `info.properties`） | `UIBackgroundModes: [audio]` を追加（バックグラウンド / ロック画面での連続再生。ドライブセッションという再生実体があるため審査上正当）。**マイク / Speech 関連の変更なし**（ドライブモードは録音しない。既存の usage description のまま） |
| `PrivacyInfo.xcprivacy` | 変更なし（新規のデータ収集・Required Reason API なし。`MPNowPlayingInfoCenter` / `AVSpeechSynthesizer` は対象外） |
| App target | 変更不要（`AppFeature` 経由で `DriveModeFeature` がリンクされる） |
| テストターゲット | `DriveModeFeatureTests`（hostless。既存と同型: `GENERATE_INFOPLIST_FILE: YES`・必要製品を直接リンク — `DriveModeFeature` / `Persistence` / `AudioEngine` / `ContentKit` / `Analytics` + core の `DriveKit` / `HabitKit` / `SRSKit` / `ContentCore` / `LanguageKit`）を追加し、scheme `SnapSpeakiOSTests` の build / test に登録 |
| `.swiftlint.yml` | 変更不要。注意 2 点: (1) `drive.announce.*` など `Text()` 非経由の文言はカスタムルール対象外 → レビュー担保、(2) `file_length` 400 — View は開始 / グランス / ノートでファイル分割済みの構成にする |
| `Packages/SnapSpeakiOS/Package.swift` | `DriveModeFeature` target / product 追加。`AudioEngine` に新規ファイル追加（依存追加なし。`MediaPlayer` はシステムフレームワーク） |
| `Packages/SnapSpeakCore/Package.swift` | §1.1 のとおり `DriveKit` 追加 |

---

## 4. テスト戦略（担保範囲の分離）

### 4.1 Linux（`swift test`）で担保

- `DriveKitTests`: §1.5 の B1〜B11・C1〜C7（スクリプト生成とカーソルの全境界）。
- `AnalyticsCoreTests`: 新イベント 3 種の追加（既存テストの網羅パターンに合わせる）。

### 4.2 macOS CI hostless で担保

| 対象 | ケース |
|------|--------|
| `DrivePlanResolver` | due / new の順序保存・courseId + itemId 解決・欠損スキップ・重複除外・`l1Text` / `l2Text` / 言語タグの写像・プラン空の `repeatFillItems` |
| `DriveSessionViewModel`（`DriveSequencing` フェイク注入） | itemCompleted → Attempt 記録呼び出しとノート行蓄積 / finished → `drive_session_completed`（endReason・usedTTSFallback）/ 開始時 `drive_session_started` / pause・resume の状態反映 |
| `DriveAttemptRecorder`（in-memory `PersistenceActor`） | 未採点 Attempt が追記される（payload roundtrip: 外側バージョン 2 / 3・`context == "drive"`）/ `ReviewEvent` が 0 件 / `AttemptHabitResult` 経由で `streak_day_recorded` / `goal_met` が一回性を保って発火 / due カードの `dueAt` が不変 |
| `SettingsView` 系（既存パターン） | ドライブ設定 3 項目の読み書き |

### 4.3 実機でしか検証できない項目（ユーザー向けチェックリスト。CI 対象外）

> 前提: シード音声はダミーバイトのため、**ファイル再生経路の聴感確認は本番収録音声への差し替え後**。それまでの実機確認は TTS 経路で行う（それが初期の正本経路でもある）。

- [ ] 実車（または車載相当の BT オーディオ）で 10 分セッションが画面操作なしで完走する（A2DP 音質・TTS の聞き取りやすさ・ポーズ長の体感）
- [ ] ステアリングリモコン / ロック画面: 再生・一時停止・次へ・前へが ux-design §10.7 の意味論で動く
- [ ] NowPlaying 表示（タイトル・コース名 + 進捗・再生状態）。学習テキストが表示されないこと
- [ ] 電話着信 → 自動一時停止 → 通話終了 → 自動再開（現在 Item の頭から）。Siri 起動でも同様
- [ ] ナビ音声（ダッキング型）と共存して続行する。割り込み型ナビで一時停止 → 再開
- [ ] BT 切断（エンジン停止相当）で即一時停止し、内蔵スピーカーで鳴らない。再接続後にリモコン再生で再開
- [ ] 画面ロック・バックグラウンドで 20 分連続再生（熱・バッテリー・音切れ）
- [ ] `AVSpeechSynthesizer` の実発話品質（ja / en ボイス、Enhanced ボイス導入時の差）
- [ ] ドライブ完了分が当日のゴール / ストリークに算入され、ホーム・サマリ表示と整合する
- [ ] グランスビューの視認性（車載ホルダー距離・直射日光下・Dynamic Type 最大）

シミュレータ確認（任意・CI 外）: `AVSpeechSynthesizer` はシミュレータでも動作するため、シーケンス進行・画面遷移・NowPlaying API 呼び出しはシミュレータで一次確認できる。リモコン・割り込み・BT は実機のみ。

---

## 5. 実装順序（コミット粒度）

PR は 1 本（`develop` 向け）。タイトルは Conventional Commits（例 `feat: drive mode MVP (audio-only hands-free sessions)`）。**各コミット後に CI green を確認**する。

| # | コミット | 内容 | 検証 |
|---|----------|------|------|
| D1 | `feat(core): DriveKit（スクリプト生成とカーソル）` | §1 一式 + B1〜B11・C1〜C7 | **Linux `swift test`** — 実装済み |
| D2 | `feat(core): drive 分析イベントを追加` | §2.4 + AnalyticsCore テスト | Linux — 実装済み |
| D3 | `feat(persistence): ドライブ設定フィールドを追加` | §2.3 の UserSettings / DTO（payload は D5）+ PersistenceTests 追記 | ios-macos — 実装済み |
| D4 | `feat(audio): TTS クライアントとドライブシーケンサ` | §2.1（`SpeechSynthesisClient` / `SequenceFilePlayer` / `DriveSequencer` + Recovery 接続。RemoteCommand は D7） | ios-macos — 実装済み |
| D5 | `feat(drive): DriveModeFeature（resolver / recorder / VM / 3 画面）` | §2.2 + §2.3 payload + xcstrings（§2.6）+ `DriveModeFeatureTests` target（project.yml）+ architecture §2.1 / §7.4 同期 | ios-macos — 実装済み |
| D6 | `feat(app): ホーム導線と配線、バックグラウンドオーディオ` | §2.5 + `UIBackgroundModes` + Settings 追加 UI | ios-macos — 実装済み |
| D7 | `feat(audio): リモコンと NowPlaying` | `DriveRemoteCommandBridge`（薄い橋。ロジックなし） | ios-macos（動作は §4.3 実機）— 実装済み |
| D8 | `docs: ドライブモード実装結果を反映` | 本計画の消し込み・roadmap チェック更新・ux-design §10 の数値 / 文言確定反映 | レビュー — 実装済み |

依存: D1 → D4 / D5（型が前提）。D2 → D5。D3 → D5 / D6。D4 → D5 → D6 → D7。docs 同期は各コミットにも含める（D8 は最終確認）。

---

## 6. リスクと対応

| リスク | 影響 | 対応 |
|--------|------|------|
| `AVSpeechSynthesizer` の delegate 完了通知が割り込み・キャンセル時に来ない / 二重に来る | シーケンサのハング・フェーズ飛び | continuation を一回性ガードで包む。`pause` / `stop` 時は `stopSpeaking()` → continuation を明示 resume。タイマー併用はしない（完了通知のみを進行条件にする） |
| ダミーシード音声で `AVAudioFile` が throw | ファイル経路が常に fallback | 仕様どおり（TTS が初期の正本経路）。`usedTTSFallback` を payload / 分析で観測し、本番音声差し替え後にファイル経路の実機確認を行う |
| 割り込み後の audio session 再活性化失敗 | 自動再開が無音のまま進む | resume 時に `activatePreview()` を再実行し、失敗したら pause に戻して `paused(reason: .audioSessionFailure)` を発行（グランスビューに一時停止中と出る。無音で進行しない） |
| `MPRemoteCommandCenter` がホストレスでテスト不能 | リモコン経路の回帰が CI で見えない | 橋を薄く保ち（コマンド → シーケンサ API 1:1）、意味論は `DriveCursor`（Linux）で固定。実機チェックリスト §4.3 で担保 |
| 自動再生によるストリーク水増し懸念（P6） | 習慣指標の信頼低下 | 完了定義（発話ポーズ含む全フェーズ再生・pause で停止・skip は数えない・明示開始のみ）を C1 / C2 / C4 テストで固定 |
| Swift 6 strict concurrency（`AVSpeechSynthesizerDelegate` は non-Sendable） | ビルド不能 | delegate を専用の `@unchecked Sendable` 最小クラスに閉じ、continuation 経由でのみ actor と通信（既存 `RecoveryObserver` と同じパターン） |
| `TodayPlanService.makeToday` の due が「今日のプラン」と同一で、ドライブ後もホームの復習件数が減らない | ユーザーの混乱 | 仕様（ux-design §10.3）。`drive.note.review_hint` で説明。ダッシュボード導入時に「ドライブで触れた」表示を検討（本計画外） |
| 車載機の AVRCP 実装差（play/pause が来ない・二重に来る） | 特定車種で操作不能 | 標準 4 コマンドに限定し、`togglePlayPause` を必ず登録。実車での機種差は §4.3 チェックリストに記録して判定表を育てる |
| セッション長の推定誤差（TTS 実長 ≠ 推定） | 10 分設定が 12 分になる等 | 許容する（Item 単位切り詰めの仕様）。推定係数は `DriveTimingPolicy` に集約してあり、実測ログで校正できる |

## 7. スコープ外（本計画では実装しない）

- CarPlay（ux-design §10.10。entitlement 取得後に別判断）
- 運転中・停車中のマイク採点（設定キーも置かない。roadmap「載せないもの」に追記済み）
- ウィジェット / App Intents / Siri ショートカットからのセッション開始
- セッションの復元（アプリ強制終了後）
- ドライブノートの永続化・履歴一覧（Attempt payload から将来導出）
- 2 話者掛け合い形式の復習音声・サーバー TTS（Phase 3 以降の別判断）
- 通知の追加（ドライブ専用リマインダーは置かない）

## 8. 実行担当への注意（要約）

1. **ロジックは DriveKit（core）に寄せる。** iOS 側シーケンサは「フェーズを 1 個再生して `phaseFinished` を返す」以上の判断をしない。進行の意味論を iOS 側に書き始めたら設計から外れている。
2. **iOS 側はローカルでビルドできない。** 1 コミットごとに `ios-macos` を回す。D1 / D2 を先に完了させ、core の型を安定させてから iOS に進む。
3. **UI 文字列と TTS 文言は必ず String Catalog。** `drive.announce.*` は lint に掛からないため特に注意（`String(localized:)` 経由）。
4. **`ReviewEvent` を書かない・`foldSRSCard` を呼ばない。** ドライブ完了は `appendAttemptEvaluatingHabit` のみ。うっかり SRS を進めると ux-design §10.8 違反（レビューで必ず確認）。
5. **AudioEngineActor に手を入れない。** 割り込みポリシーの差分を既存クラスに if で足すと通常レッスンの復旧仕様（architecture §3.9）が壊れる。
6. **docs 同期は同一コミット**（architecture §2.1 / §7.4、ux-design §10 の確定値、roadmap チェック）。
7. **テストの期待値は ux-design §10 から導く。** 実装に合わせて仕様を曲げない。曖昧な場合は本計画の該当項を正とする。
