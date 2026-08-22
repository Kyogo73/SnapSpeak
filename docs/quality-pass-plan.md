# 品質改善計画（Quality Pass）— 実行指示書

本書は、docs と実装の全面監査（設計書整備パス）で確定した品質改善の**実行計画**である。実行担当はコード・テスト・`Resources/Localizable.xcstrings`・`App/project.yml`、および変更に対応する docs の同期を編集してよい。CI 設定（`.github/workflows/`）の変更は不要（新規テストターゲットは `App/project.yml` の scheme 追加だけで `ios-macos` に取り込まれる）。

関連文書: [architecture.md](./architecture.md)（設計正本）/ [ux-design.md](./ux-design.md)（UX 正本）/ [phase2-retention-implementation-plan.md](./phase2-retention-implementation-plan.md)（継続機能の実装記録）/ [development-workflow.md](./development-workflow.md)（ブランチ・コミット規約）。

## 0. 前提と原則

- **ベースライン**: core（`Packages/SnapSpeakCore`、Linux `swift test`）147 テスト green / iOS hostless（macOS CI）32 テスト green / SwiftLint strict green。**各コミットでこの green を維持する。**
- **安全なリファクタと挙動変更を分離する**: 挙動を変えないリファクタ（§1）と、仕様是正・堅牢化（§2・§3）を**別コミット**にする。純移動（ファイル分割）はそれ単独のコミットにする（diff レビューと `git blame` のため）。
- **Linux VM の制約**: `Packages/SnapSpeakiOS` はローカルでコンパイルできない。iOS 側を触るコミットは毎回 `ios-macos` CI で確認する（CI をコンパイラとして使う既存運用。AGENTS.md 参照）。
- **docs 同期規約**: 公開 API・UI 文言・仕様を変えるコミットは、**同一コミット**で該当 docs（architecture §該当節 / ux-design §該当節 / phase2 記録）を更新する。
- **不変条件**（roadmap「フェーズ横断の不変条件」）を厳守: TCA 禁止・core は Apple フレームワーク import 禁止・UI 文字列は String Catalog・`ReviewEvent` 追記型・オンデバイス ASR 厳格・`AppleLanguages` 書換え禁止。
- SwiftLint: `file_length` 400 行 / コード内日本語リテラル禁止（`no_hardcoded_ui_japanese`）。`ReminderContent` のような `Text()` 非経由の文言はルールに掛からないため `String(localized:)` 経由をレビューで担保する。

---

## 1. リファクタリング（挙動を変えない）

### R1. `appendAttemptEvaluatingHabit` の未使用引数 `now` を削除（既知課題 5）

- **対象**: `Packages/SnapSpeakiOS/Sources/Persistence/PersistenceActor+Habits.swift`
- **現状**: `now: Date = Date()` を受け取るが実装内で `_ = now` として未使用（学習日は `write.createdAt` で判定）。
- **方針**: パラメータ `now` と `_ = now` を削除し、シグネチャを次にする:

```swift
public func appendAttemptEvaluatingHabit(
    _ write: LessonAttemptWrite,
    timeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier
) throws -> AttemptHabitResult
```

- **呼び出し側**: `CompositionUseCase.swift`（`persist(outcome:...)` 内）と `ShadowingUseCase.swift`（`stopAndScore` 内）は既定引数呼びのため変更不要。`Tests/PersistenceTests/PersistenceHabitTests.swift` の全呼び出し（12 箇所）から `now:` ラベルを削除する。「now が翌学習日でも createdAt が同日なら streak は再発火しない」テストは、**引数が消えたことで検証対象が消える**ため、テスト名と本文を「createdAt が学習日を決める」ことの検証（`utcDate` 固定）に書き換えて残す。
- **docs 同期**: phase2 記録 §4.1 の「実装差分」注記（`_ = now` の記述）を削除し、確定シグネチャに更新。

### R2. `CourseCatalog` の同一 courseId・同一 revision tie-break を決定化（既知課題 6）

- **対象**: `Packages/SnapSpeakCore/Sources/ContentCore/CourseCatalog.swift`
- **現状**: `uniquedActiveReleases` は `revision(existing) >= revision(item)` で先勝ちのため、**同一 revision の重複は入力順で勝者が変わる**。また最終 sort の `revision(lhs) > revision(rhs)` 分岐は（id 一意化後のため）到達しない死コード。
- **方針**: 第 3 クロージャを追加して決定化する:

```swift
public static func uniquedActiveReleases<T>(
    _ items: [T],
    id: (T) -> String,
    revision: (T) -> Int,
    releaseId: (T) -> String? = { _ in nil }
) -> [T]
```

  同一 `courseId` かつ同一 `revision` のとき: (1) `releaseId` 非 nil（= downloaded 由来）を seed（nil）より優先、(2) 双方非 nil なら `releaseId` の辞書順で大きい方、(3) 双方 nil なら既存維持。sort 内の死んだ revision 分岐を削除。
- **呼び出し側**: `ContentKit/CourseStore.allCourses()` と `ReviewFeature/TodayPlanService.lessonSummaries(from:)` に `releaseId: { $0.releaseId }` を渡す。
- **注記**: 未定義（入力順依存）だった挙動をテストで固定するもので、既存テストの期待値は変えない。
- **テスト（Linux）**: `Tests/ContentCoreTests/CourseCatalogTests.swift` に「同一 courseId・同一 revision で releaseId 非 nil が勝つ」「双方 nil は先勝ち」「入力逆順でも結果一致」を追加。

### R3. `uniquedActiveReleases` の冗長な多重適用を解消

- **対象**: `Packages/SnapSpeakiOS/Sources/ReviewFeature/TodayPlanService.swift`
- **現状**: `CourseStore.allCourses()` が一意化済みを返すのに、`makeToday` が再適用し、さらに `lessonSummaries(from:)` 内でも適用している（計 3 回）。
- **方針**: `makeToday` 内の再適用を削除し `allCourses()` の結果をそのまま使う。`lessonSummaries(from:)` は任意入力を受ける静的純関数のため一意化を**保持**する（既存テスト「同一 courseId の seed/downloaded は revision 最大だけ残す」が依存）。挙動不変。

### R4. 肥大化ファイルの予防分割（SwiftLint `file_length` 400 接近）

対象は 2 ファイル（**宣言の純移動のみ**。リネーム・ロジック変更を混ぜない）:

| ファイル | 現行 | 分割案 |
|----------|------|--------|
| `Persistence/DTO.swift` | 355 行 | `DTO.swift`（LessonAttempt / ReviewEvent 系 Write・DTO）、`DTO+SRS.swift`（`SRSCardDTO` / `SRSCardFoldRequest`）、`DTO+Settings.swift`（`UserSettingsDTO` / `AttemptHabitResult` / 既定値） |
| `Persistence/PersistenceActor.swift` | 353 行 | `PersistenceActor.swift`（コンテナ生成・Attempt / ReviewEvent / SRSCard fold）、`PersistenceActor+Settings.swift`（`loadOrCreateSettings` / `saveSettings` / `requireSettings`）、`PersistenceActor+Downloads.swift`（DownloadedCourse CRUD） |

`CompositionUseCase.swift`（301 行）は閾値まで余裕があるため今回は分割しない（B3 で微減する）。

### R5. `ShadowingUseCase.startPlayback` の未使用引数 `asrReady` を削除

- **対象**: `Packages/SnapSpeakiOS/Sources/ShadowingFeature/ShadowingUseCase.swift`（protocol と `LiveShadowingUseCase` の両方）
- **現状**: `startPlayback(item:stored:rate:asrReady:)` の `asrReady` は `_ = asrReady` で未使用。
- **方針**: パラメータを削除。呼び出し側 `ShadowingLessonViewModel.swift` の 1 箇所を更新。`stopAndScore` の `asrReady` は**使用中**のため変更しない。

### R6. 小規模クリーンアップ（1 コミットに集約可）

- `ReviewFeature/ReviewSessionViewModel.swift`: `resolveEntries` 内の未使用 `fallbackMode`（`let fallbackMode = ...` と `_ = fallbackMode`）を削除。`load()` と `startResolved(entries:skipped:)` の末尾（intro / running / summary への分岐）が重複しているため private ヘルパ `begin(at:)` に抽出。
- `AppFeature/HomeView.swift`: `planSummary` の新規のみ分岐だけ `String(localized:)` 直呼びで他と不統一 → `LocalizedFormat.string("home.today.plan_new_only")` に統一（挙動同一）。
- `Resources/Localizable.xcstrings`: **未参照キー 2 件を削除** — `home.today.review_count` / `home.today.new_lesson`（計画時のキー。実装は `home.today.plan_*` 3 態に置換済み。全キー突合で未参照を確認済み）。phase2 記録 §5 の注記を「削除済み」に更新。

### R7. テスト用の依存シーム導入（挙動不変の DI。§4 のテスト前提）

現状 `OnboardingViewModel` / `TodayViewModel` / 各 UseCase は具象型（`PersistenceActor` / `TodayPlanService` / `SpeechClient` / `AudioEngineActor`）に依存し、**失敗注入・遅延注入ができない**。以下の最小プロトコルを導入する（実装の差し替えはなし。既存型を準拠させ、プロパティ型を `any P` にするだけ）:

| プロトコル | 置き場 | 要求 | 準拠 | 使う側 |
|-----------|--------|------|------|--------|
| `SettingsStoring` | `Persistence` | `loadOrCreateSettings() async throws -> UserSettingsDTO` / `saveSettings(_:) async throws -> UserSettingsDTO` | `PersistenceActor` | `OnboardingViewModel` |
| `TodayPlanning` | `ReviewFeature` | `makeToday(now:timeZone:goal:policy:) async throws -> TodaySnapshot` | `TodayPlanService` | `TodayViewModel` |
| `SpeechRecognizing` | `SpeechKit` | `recognize(url:locale:timeout:) async throws -> [SpeechTranscriptSegment]` | `SpeechClient` | `LiveCompositionUseCase`（`LiveShadowingUseCase` は任意） |

注意: いずれも `Sendable` 制約付き。actor の準拠は要求が全て `async` なのでそのまま満たせる。`AudioEngineActor` のプロトコル化は影響半径が大きいため**今回はやらない**（T7 は composition 経路に絞る。audio 呼び出し `stop()` / `startRecordOnly` はテストでは実 actor を使い、録音ファイルはダミー URL で足りる — 認識は `SpeechRecognizing` フェイクが返すため実音声不要）。`AppDependencies` の生成コードは具象のまま（注入点の型だけ `any P` に広げる）。

---

## 2. UI/UX 是正（ux-design 準拠。コードレビューで検出可能な範囲）

> ux-design.md は UX 正本のため、本節は**実装を仕様に合わせる**（docs 側は文言確定時の反映のみ）。実機でしか確認できない項目は §5.2 のチェックリストへ分離した。

### U1. サマリのスキップ文言是正（既知課題 1）

- **現状**: `ReviewSessionViewModel.skippedCount` が「教材欠損による除外」と「マイク拒否等のユーザースキップ」の合算で、サマリは常に `review.summary.skipped`（「教材が見つからないため %lld 問スキップしました」）を表示する。マイク拒否スキップに対して誤解を招く（ux-design §4.4 はこの文言を欠損コンテンツ専用と定義）。
- **方針**: カウンタを分離し、サマリを 2 行に分ける。
  - `ReviewSessionViewModel`: `skippedCount` を廃止し `skippedMissingCount`（`resolveEntries` の解決不能分）と `skippedByUserCount`（`skip()` の増分）の 2 つの `@Published` に分離。
  - `Resources/Localizable.xcstrings`: 新キー `review.summary.skipped_user` = 「%lld 問スキップしました」を追加（既存 `review.summary.skipped` の値は変更しない）。
  - `ReviewSummaryView` / `ReviewSessionView` / `ReviewSessionContainer`: 両カウントを受け渡し、各 > 0 のときのみ該当行を表示。
- **テスト**: `TodayPlanServiceTests` の `resolveEntriesSkipsMissing` / `skipDoesNotIncrementCompletedCount` を新プロパティ名に更新し、「欠損とユーザースキップが混ざらない」ケースを追加。
- **docs 同期**: ux-design §3.3（セッション側が足すもの）と §4.4 の欠損行に「ユーザースキップは別行（`review.summary.skipped_user`）」を追記。phase2 記録 §4.3 の `skippedCount` 注記を分離後の名前に更新。

### U2. セッションサマリにゴール進捗を表示（ux-design §4.5）

- **現状**: サマリは完了数・スキップ・`goal_met`・ストリーク更新のみで、§4.5 ワイヤーフレームの「今日 12/10 問」（ゴール進捗）が出ない。
- **方針**: `ReviewSessionContainer` が `afterSnapshot?.goal` から `completedItems` / `goalItems` を `ReviewSummaryView` に渡し、既存キー `home.goal.progress`（今日 %1$lld / %2$lld 問）で 1 行表示する（`afterSnapshot` 未取得時は非表示）。新キー不要。

### U3. ホームのナビゲーションタイトルを仕様に合わせる（ux-design §4.3）

- **現状**: `HomeView` の `navigationTitle` が `"tab.home"`（ホーム）。§4.3 ワイヤーフレームの nav は「今日の学習」。
- **方針**: `navigationTitle("home.title")` に変更（タブラベルは `tab.home` のまま）。カード見出しの `home.title` 併用は §4.3 ワイヤーフレームどおりなので変更しない。

### U4. ストリークルールの初回説明（ux-design §3.4）

- **現状**: 「連続 2 日休むと途切れる」の説明（`streak.rule_note`）は回復カードにしか出ず、§3.4 の「**初回のストリーク獲得時**とこのカードで説明する（隠しルールにしない）」を満たさない。
- **方針**: `HomeView.habitCard` で `snapshot.streak.currentStreakDays == 1` のとき `streak.rule_note` をキャプションで表示する（新しいストリークの初日 = 獲得直後。専用の永続フラグは追加しない。ストリーク 2 日目以降は自然に消える）。
- **docs 同期**: ux-design §4.3 の StreakBadge 行に表示条件を 1 文追記。

---

## 3. 堅牢性（挙動変更を含む。リファクタと分離する）

### B1. SwiftData `save()` 失敗時の rollback（既知課題 2）

- **対象**: `Persistence/PersistenceActor.swift`（7 箇所）と `Persistence/PersistenceActor+Habits.swift`（5 箇所）の全 `try modelContext.save()`（計 12 箇所）。
- **現状**: save 失敗時に挿入・変更済みのモデルが context に残り、次の save で意図しない部分状態が確定しうる。
- **方針**: PersistenceActor に private ヘルパを追加し、全 save を置換する:

```swift
/// save 失敗時に未保存変更を巻き戻してから rethrow する（部分状態を残さない）。
private func saveOrRollback() throws {
    do {
        try modelContext.save()
    } catch {
        modelContext.rollback()
        throw error
    }
}
```

  適用は機械的な置換であり、成功経路の挙動は不変。`appendAttemptEvaluatingHabit` は元々単一 save 設計なので、rollback で Attempt・markers・lastKnown が**揃って**巻き戻る（部分喪失しない）ことをコメントで明記する。
- **テスト**: SwiftData の save 失敗を決定的に注入する公式手段がないため、(1) `modelContext.rollback()` が未保存 insert を消すことを確認する小テスト（insert → rollback → fetch 0 件）を `PersistenceActorTests` に追加し、(2) ヘルパが全 save 箇所に適用されていることは `rg "modelContext.save\(\)"` が `saveOrRollback` 内の 1 箇所だけになることで担保する。

### B2. `onboarding_skipped` の重複発火防止（既知課題 3）

- **対象**: `OnboardingFeature/OnboardingViewModel.swift` の `skip()`
- **現状**: `analytics.track(.onboardingSkipped(...))` が保存**前**に発火するため、保存失敗 → 再試行で同イベントが重複する（`completeGoalStep` は保存成功後に track しており非対称）。
- **方針**: `skip()` の track を保存成功後（`onboardingCompleted` の直前）へ移動し、`completeGoalStep` と同型にする。
- **テスト（hostless、R7 の `SettingsStoring` シーム使用）**: 新規 `OnboardingFeatureTests`（`App/project.yml` に hostless target 追加、scheme `SnapSpeakiOSTests` へ登録）で、「1 回目 saveSettings 失敗 → nil 返却・イベント 0 件」「2 回目成功 → `onboarding_skipped` 1 件・`onboarding_completed` 1 件」「`completeGoalStep` 失敗 → 再試行でも `onboarding_completed` 1 件」を固定。
- **docs 同期**: ux-design §9 の `onboarding_skipped` 発火点を「各画面のスキップ（保存成功時に 1 回）」へ更新。

### B3. Composition Attempt payload の型是正

- **対象**: `CompositionFeature/CompositionUseCase.swift` の `persist(outcome:...)`
- **現状**: payload が `["payloadSchemaVersion": "1", "passed": "true" | "false" | "unscored"]` の `[String: String]` で、スキーマ番号が文字列・真偽値がラベル文字列。shadowing 側（architecture §4.6 の `ShadowingScore` 構造体）と非対称で、Phase 3 同期時のデコードが脆い。
- **方針**: `CompositionFeature` に Codable 構造体を定義して encode する（未リリースのため互換不要 — architecture §7.4 の「未リリース限定」判断と同根拠。`payloadSchemaVersion` は 1 のまま）:

```swift
struct CompositionAttemptPayload: Codable, Sendable {
    var payloadSchemaVersion: Int  // 1
    var result: String             // "pass" | "fail" | "unscored"
    var usedHint: Bool
    var latencyMs: Int
}
```

- **テスト**: encode → decode roundtrip と、`.unscored` のとき `ReviewEvent` を書かない既存挙動の維持（`CompositionGrade.shouldAppendReviewEvent`）を確認する単体テスト。hostless target を増やさずに済むよう、payload 構造体は `CompositionFeature` 内に置きテストは `ReviewFeatureTests` に同居させない — **`OnboardingFeatureTests` と同時に作る新 hostless target `CompositionFeatureTests`** に置く（`App/project.yml` 同型定義）。

---

## 4. 自動テスト追加

既存テストの命名・配置は型別 Suite で整理済みのため**再編は不要**（`PersistenceTestSupport.swift` のヘルパ集約も維持）。追加分のみ列挙する。

### 4.1 Linux（core。`Packages/SnapSpeakCore/Tests/`）

| # | 対象 | ケース | 紐づく変更 |
|---|------|--------|-----------|
| T1 | `ContentCoreTests/CourseCatalogTests` | 同一 courseId・同一 revision: releaseId 非 nil 優先 / releaseId 辞書順 / 双方 nil は先勝ち / 入力逆順で結果一致 | R2 |
| T2 | `HabitKitTests/HabitAnalyticsTests` | 目標を当日中に下げた場合（`itemsTodayBefore >= 新 goal`）は `goal_met` が発火しないことを現仕様として固定（ux-design §2.2「遡及計算はしない」の境界） | なし（仕様固定） |
| T3 | `HabitKitTests/SessionPlannerTests` | `maxReviews = 0` のエッジ（全件 deferred・newLesson は方針どおり） | なし（仕様固定） |

### 4.2 macOS CI hostless（`Packages/SnapSpeakiOS/Tests/` + `App/project.yml`）

| # | 対象（target） | ケース | 紐づく変更 |
|---|----------------|--------|-----------|
| T4 | `OnboardingFeatureTests`（新規 target） | B2 の失敗経路一式 / `saveFailed` フラグの立ち下がり / リマインダー拒否時に `reminderEnabled=false` で保存される | R7・B2 |
| T5 | `AppFeatureTests`（新規 target。`TodayViewModel` 用） | refresh 競合: 遅い `TodayPlanning` フェイク（`Task.sleep`）の第 1 世代が、後続 refresh の結果を上書きしない / `makeToday` throw → `state == .failed` / `regeneratePlanThenStart` は failed のとき false（古い snapshot の plan で開始しない） | R7 |
| T6 | `ReviewFeatureTests` 追記 | Item identity: `ReviewEntry.id` が due / new 判別子込みで一意 / 別コースの同名 itemId を混同しない / U1 分離後の欠損・ユーザースキップが独立に数えられる | U1 |
| T7 | `CompositionFeatureTests`（新規 target） | 空 ASR: `SpeechRecognizing` フェイクが空 transcript を返す → `finishRecording` が `.unscored`・Attempt 追記・`ReviewEvent` 0 件 / 認識 throw → 同様に unscored / B3 payload の roundtrip | R7・B3 |
| T8 | `NotificationsKitTests` 追記 | `"reminder-"` prefix 以外の pending 通知を消さない（`FakeReminderCenter` に pending 種まき setter を追加） | なし（仕様固定） |
| T9 | `PersistenceTests` 追記 | rollback が未保存 insert を消す（B1 参照） | B1 |

新規 hostless target（`OnboardingFeatureTests` / `AppFeatureTests` / `CompositionFeatureTests`）は `App/project.yml` の既存 `PersistenceTests` と同型（bundle_loader なし・必要製品を直接リンク）で定義し、scheme `SnapSpeakiOSTests` の test targets に追加する。`AppFeatureTests` は `AppFeature` 製品のリンクが必要（推移的に SwiftUI を含むが hostless ロジックテストとして成立する — 失敗する場合は `TodayViewModel` を検証可能な範囲に絞り、リンク不能の事実を PR に記録して T5 をスキップしてよい）。

---

## 5. QA チェックリスト

### 5.1 Sol の最終監査観点（コードレビュー / CI で確認可能）

**仕様適合**

- [ ] ux-design §2 のルール（04:00 境界・橋渡し 1 日・上限 20・並び順決定性・アイテム完了の定義）に対応する core テストが全て存在し green
- [ ] ux-design §5 状態マトリクスと §5.1 実装対応メモが実装と一致（特に `TodayState.failed` / 回復カード / マイク拒否）
- [ ] roadmap「フェーズ横断の不変条件」1〜9 に違反する変更がない（とくに: `ReviewEvent` 追記型のまま・SRS カード LWW なし・core に Apple import なし）
- [ ] `.unscored`（認識不能）が `.fail` の `ReviewEvent` を書いていない（architecture §5.2）

**並行性**

- [ ] `TodayViewModel.refresh` の全 `await` 復帰点に世代確認がある（新規コードを含む）
- [ ] `ReminderScheduler.sync` の世代ガード（古い ON 同期が OFF 後に通知を足さない）テストが green
- [ ] `ModelContext` が `PersistenceActor` の外に出ていない（DTO のみ境界通過）
- [ ] `@MainActor` 境界: ViewModel は `@MainActor`、UseCase / actor は Sendable 引数のみ

**i18n**

- [ ] 追加・変更キーが `Resources/Localizable.xcstrings` に存在し、コード内日本語リテラルなし（SwiftLint `no_hardcoded_ui_japanese` green）
- [ ] 件数系キーが `%lld` 変数のまま（値への焼き込みなし）
- [ ] `ReminderContent` が `String(localized:)` 経由（lint 対象外のため目視）
- [ ] 未参照キーが残っていない（全キー × `rg` 突合。R6 後は 0 件のはず）

**分析**

- [ ] イベントが ux-design §9 の表と 1:1（追加・削除なし）。ペイロードは帯・コードのみ（生値・PII なし）
- [ ] 重複発火防止: `HabitDayMarkers` 3 種 + B2 修正後の `onboarding_skipped` がそれぞれ 1 回性を持つ（テストで担保）
- [ ] `reminder_scheduled` が `add` 成功時のみ

**a11y（コードで確認可能な範囲）**

- [ ] 新規・変更 UI のタップ領域 44pt（`minHeight: 44` / `frame`）
- [ ] `ProgressRing` の `accessibilityValue`・`StreakBadge` の label / hint・進捗ヘッダの `progress_a11y` が維持されている
- [ ] 達成・警告表示が色だけに依存しない（チェック記号・テキスト併記）
- [ ] 装飾シンボルが `accessibilityHidden`

### 5.2 実機でしか確認できない項目（ユーザー向けチェックリスト）

> 前提: シード音声は現状 checksum 整合用のダミーバイトで実再生できない（AGENTS.md）。録音・再生・ASR 系は本番収録音声への差し替え後に実施する。

- [ ] 通知の実発火（daily / streak_risk の文言切替）・通知タップでホーム着地・`reminder_opened` 記録
- [ ] 通知権限 3 状態（未決定 / 許可 / 拒否）と、拒否後の Settings 導線 → 設定アプリ → 復帰後の再判定
- [ ] オンボーディング: 起動 → 最初のレッスン開始まで 60 秒以内・タップ 2 回（ux-design §3.1 バジェット）
- [ ] 復習セッションの実録音・実 ASR（機内モードでの採点完了、`en-US` オンデバイス）
- [ ] 音声経路マトリクス: 内蔵スピーカー / 受話口 / 有線 / AirPods / 他社 HFP / 着信 / Siri（roadmap Phase 1 DoD）
- [ ] マイク拒否・Speech 拒否の各組合せでの劣化フロー（スキップ導線・タイプ入力）
- [ ] Dynamic Type 最大でホーム・サマリのカードが崩れない / VoiceOver 操作順 / 録音中に VoiceOver がお手本・録音へ混入しない / Reduce Motion
- [ ] 04:00 境界と橋渡し: 03:59 / 04:00 の完了、1 日休み → 継続、2 日休み → 回復カード → 閉じる / 再開
- [ ] タイムゾーン変更（例: 東京 → ロサンゼルス）後の due 一斉到来が上限 20 で削られ「ほか n 件はまた明日」が出る
- [ ] ストリーク喪失 → 回復カードが 1 回だけ出る（閉じたら再表示しない）→ 再学習でストリーク 1 日目

---

## 6. 実行順序（コミット粒度）

PR は 1 本（`develop` 向け）。タイトルは Conventional Commits（例 `refactor: quality pass (API cleanup, robustness, tests)` — squash 後の subject になるため種別は最終内容に合わせる。挙動変更を含むため `fix:` または `refactor!:` ではなく、内容ごとに判断）。**各コミット後に CI green を確認**する。

| # | コミット | 内容 | 検証 |
|---|----------|------|------|
| Q1 | `refactor(core): CourseCatalog の tie-break を決定化` | R2 + T1 | **Linux `swift test`** |
| Q2 | `refactor(ios): 冗長コード・未使用キーの整理` | R3 + R6 + phase2 記録 §5 注記更新 | ios-macos |
| Q3 | `refactor(ios): 未使用引数の削除` | R1 + R5 + phase2 記録 §4.1 更新 | ios-macos |
| Q4 | `refactor(persistence): ファイル分割（純移動）` | R4 | ios-macos |
| Q5 | `refactor(ios): テスト用依存シームの導入` | R7（DI のみ・挙動不変） | ios-macos |
| Q6 | `fix(persistence): save 失敗時に rollback` | B1 + T9 | ios-macos |
| Q7 | `fix(onboarding): skip 分析イベントの重複防止` | B2 + T4（`OnboardingFeatureTests` target 追加） | ios-macos |
| Q8 | `fix(composition): Attempt payload を型付き Codable に` | B3 + T7（`CompositionFeatureTests` target 追加） | ios-macos |
| Q9 | `fix(review): スキップ文言の分離ほか ux-design 差分是正` | U1 + U2 + U3 + U4 + T6 + ux-design 同期 | ios-macos |
| Q10 | `test(ios): TodayViewModel と残カバレッジ` | T5（`AppFeatureTests` target 追加）+ T8 + T2 + T3 | Linux + ios-macos |
| Q11 | `docs: 品質パスの結果を反映` | 残りの docs 同期（本書のチェック消し込み、architecture / phase2 記録の最終確認） | レビュー |

依存関係: Q5 → Q7 / Q8 / Q10（シームが前提）。Q1 / Q2 / Q3 / Q4 / Q6 は独立。Q9 は Q2（キー整理）後が安全。

## 7. リスクと対応

| リスク | 影響 | 対応 |
|--------|------|------|
| iOS 側のコンパイルエラーを Linux で検出できない | 手戻り | コミットごとに `ios-macos` CI（既存運用）。core に寄せられる変更（R2）を先行 |
| `modelContext.rollback()` の巻き戻しで、保持中の `@Model` 参照が無効化される | 予期しないクラッシュ | ヘルパは throw 経路のみで発動。throw 後は呼び出し側が DTO を返さない（既存の throws 伝播設計のまま）。rollback 後にモデル参照を再利用するコードを書かない |
| R7 のプロトコル化で Swift 6 strict concurrency のエラー（actor 準拠・Sendable） | ビルド不能 | 要求を全て `async` にし、既存 actor をそのまま準拠。existential（`any P`）は `Sendable` 継承で束縛 |
| `AppFeatureTests` の hostless リンクが通らない（AppFeature が SwiftUI を広く含む） | T5 が実施不能 | §4.2 の注記どおり、リンク不能なら T5 をスキップして PR に記録（`TodayViewModel` の分離は今回のスコープ外） |
| U1 のカウンタ分離で既存テスト・呼び出しの見落とし | CI red | `rg skippedCount` で全参照を洗ってから改名。プロパティ廃止はコンパイルエラーで検出される（silent breakage なし） |
| xcstrings キー削除の誤爆（実は参照されている） | 実行時にキー名がそのまま表示される | 削除前に全キー × `rg` 突合を再実行（本監査では `home.today.review_count` / `home.today.new_lesson` の 2 件のみ未参照） |
| tie-break 決定化で既存ユーザーの表示コースが変わる | なし（未リリース） | 同一 revision 重複は seed と downloaded の境界でのみ発生し、downloaded 優先は現行の意図（revision 最大優先）と整合 |
| コミット肥大でレビュー困難 | レビュー漏れ | §6 の粒度を守る。純移動（Q4）に変更を混ぜない |

## 8. 実行担当への注意（要約）

1. **挙動変更（B・U）とリファクタ（R）を混ぜない。** 純移動は単独コミット。
2. **iOS 側はローカルでビルドできない。** 1 コミットごとに `ios-macos` を回し、赤なら直してから次へ進む。
3. **UI 文字列は必ず String Catalog。** 新キーは ux-design §8 の命名規約（`<画面>.<要素>[.<状態>]`）に従い、件数は `%lld` 変数のまま。
4. **docs 同期は同一コミット。** 特に U1（ux-design §3.3 / §4.4）、B2（ux-design §9）、R1 / R2（phase2 記録・architecture）。
5. **テストの期待値を実装に合わせて曲げない。** 期待値は ux-design / architecture の仕様から導く。仕様が曖昧な場合は本書の該当項の方針を正とする。
6. スコープ外: StoreKit / Paywall、ダッシュボード、`AudioEngineActor` のプロトコル化、実機依存の検証（§5.2 はユーザーに委ねる）。
