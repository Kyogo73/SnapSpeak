# 進捗ダッシュボード実装計画（Phase 2 残スコープ C1）

本書は [roadmap.md](./roadmap.md) Phase 2「進捗ダッシュボード」を実装 PR に落とす計画である。設計判断の正本は [architecture.md](./architecture.md)、UX 正本は [ux-design.md](./ux-design.md)（本実装で §4.8 を新設し §5・§8 に追記）。フェーズ定義・不変条件は roadmap.md が勝つ。

> **状態: 実装中（`cursor/progress-dashboard-0083`）。** GitHub Actions が課金制限で停止中のため、iOS 側の CI 検証（`ios-macos`）は課金修復後に実施する。core は Linux `swift test`、lint は Linux SwiftLint で先行検証する。

## 0. 要件（roadmap Phase 2 より）

- 連続学習日（学習日境界 04:00）・週間完了・モード別平均スクリプト一致率を表示する。
- 個人データはローカルのみ。**ローカル履歴だけで描画され、オフラインで開ける**（DoD）。
- 集計は **PersistenceActor 経由**（architecture §14）。
- 指標名は「スクリプト一致率」。**発音精度と誤認させない**（不変条件 8）。

## 1. 設計判断

### 1.1 モジュール配置（検討 3 案）

| 案 | 内容 | 判定 |
|----|------|------|
| A | 集計純関数を `HabitKit` に追加し、UI は `AppFeature` 内に `DashboardView` | **採用** |
| B | 新 target `DashboardFeature` を切る | 否。`App/project.yml` の変更（scheme・テスト target）が必要になり、CI 停止中に統合リスクを増やす。画面 1 枚 + VM に target は過剰 |
| C | SwiftData 集計を iOS 側だけで行う | 否。Linux テスト不能。「core 純関数 + Linux 担保」の既存方針（phase2 計画 §0）に反する |

採用理由: `HabitKit` は「ストリーク、デイリーゴール、セッションプラン」を持つ習慣ドメインであり進捗集計は同質。`AppFeature` は既に `Persistence` / `HabitKit` / `CompositionFeature` / `ShadowingFeature`（HomeView 経由）/ `DesignSystem` / `Analytics` に依存しており、**依存追加ゼロ**で完結する。

### 1.2 ペイロードのデコード責務

`LessonAttempt.payloadJSON` のスキーマ型は `ShadowingScore`（ScoringKit, core）と `CompositionAttemptPayload`（CompositionFeature, iOS）。Persistence がデコードすると **インフラ → Feature の依存逆流**になるため行わない。**AppFeature の `DashboardViewModel` がデコード**し、core の入力型 `ProgressSampleItem` に写像する（既存型の再利用。二重実装しない）。

- 未知の `payloadSchemaVersion` / デコード失敗アイテムは **完了数にはカウントし、率の集計からは除外**する（追記型履歴を壊さない・未知は拒否の原則に整合）。
- 瞬間英作文 `result == "unscored"`（マイク拒否スキップ等）は率の分母に入れない。

### 1.3 集計の定義（ux-design §4.8 に同内容を記載）

- **日別バー**: 今日を含む直近 7 学習日（04:00 境界、端末タイムゾーン）。完了アイテム数と、当時ではなく**現在の**デイリーゴールに対する達成表示（ux-design §2.2「遡及計算はしない」と整合: 過去日の達成表示は参考値であることを注記）。0 件日も 0 のバーとして埋める。
- **週間完了**: 上記 7 学習日の完了アイテム合計。
- **モード別平均**: 直近 30 学習日窓。シャドーイング = `scriptMatchRate` の単純平均、瞬間英作文 = `pass / (pass + fail)`。各サンプル数を併記し、`0 件` の場合は「まだデータなし」を表示。
- **ストリーク**: 既存 `StreakCalculator.snapshot`（全履歴 `attemptActivityDates()` 入力）を再利用。current / longest / total を表示。

## 2. SnapSpeakCore: HabitKit 追加 API

`Sources/HabitKit/ProgressSummarizer.swift`（新規 1 ファイル）。乱数なし・`Date` / `Calendar` 注入・全型 `Sendable`（既存 HabitKit 規約）。

```swift
public enum ProgressMode: String, Sendable, Equatable { case shadowing, composition }

/// ダッシュボード集計の入力サンプル（payload デコード済みの最小値）。
public struct ProgressSampleItem: Sendable, Equatable {
    public var createdAt: Date
    public var mode: ProgressMode
    public var scriptMatchRate: Double?   // shadowing のみ
    public var passed: Bool?              // composition のみ。unscored は nil
    public init(createdAt: Date, mode: ProgressMode, scriptMatchRate: Double? = nil, passed: Bool? = nil)
}

public struct DailyProgressBar: Sendable, Equatable {
    public var dayStart: Date        // 学習日開始（04:00 境界）
    public var completedItems: Int
    public var goalMet: Bool         // 現在の goalItemsPerDay 基準
}

public struct ProgressSummary: Sendable, Equatable {
    public var streak: StreakSnapshot
    public var dailyBars: [DailyProgressBar]      // 古い→新しい順で 7 要素固定
    public var weekCompletedItems: Int
    public var shadowingAverageMatchRate: Double? // サンプル 0 なら nil
    public var shadowingSampleCount: Int
    public var compositionPassRate: Double?       // pass+fail が 0 なら nil
    public var compositionScoredCount: Int        // pass + fail 件数
}

public enum ProgressSummarizer {
    /// - activity: 全履歴の LessonAttempt.createdAt（ストリーク・total 用）
    /// - windowSamples: 直近 30 学習日ぶんのサンプル（バー・平均用。呼び出し側が期間で絞る）
    public static func summarize(
        activity: [Date],
        windowSamples: [ProgressSampleItem],
        goalItemsPerDay: Int,
        now: Date,
        calendar: Calendar,
        dayBoundaryHour: Int = StudyDay.defaultBoundaryHour,
        grace: StreakGracePolicy = .bridgeSingleRestDay
    ) -> ProgressSummary
}
```

集計仕様の詳細: 日別バーは `StudyDay.studyDay(of:)` でバケット化し、`now` の学習日を末尾に直近 7 学習日（暦日連続。休み日も含む）を生成。窓外サンプルは無視する。平均は `Double` 単純平均で丸めない（表示側でフォーマット）。

## 3. Persistence 追加 API

`PersistenceActor+Habits.swift` に期間クエリを 1 本追加する（集計は PersistenceActor 経由の規約に従い、データ取得のみ担う）。

```swift
/// 期間内の LessonAttempt（createdAt 昇順、半開区間 [start, end)）。
public func attempts(from start: Date, to end: Date) throws -> [LessonAttemptDTO]
```

呼び出し側（DashboardViewModel）は `始点 = 今学習日の開始 - 30 日`、`終点 = 遠い将来` で取得する。既存 `attemptActivityDates()` をストリーク入力に使う。

## 4. AppFeature: 画面と配線

- `Navigation.swift`: `HomeDestination` に `case progress` を追加。
- `HomeView.swift`: habitCard の下に「進捗を見る」の遷移行（`Button` → `path.append(.progress)`、44pt 領域、`chevron` アイコン）。
- `RootView.swift`: `homeDestination` の `switch` に `.progress` → `DashboardView(persistence: dependencies.persistence)` を追加。
- `DashboardView.swift`（新規）: `@StateObject` で `DashboardViewModel(persistence:)` を保持。セクションは (1) ストリークカード（current / longest / total、`StreakBadge` 再利用）、(2) 直近 7 日の `Swift Charts` 縦棒（`BarMark`。値ラベル併記で色だけに依存しない。ゴール達成日はアクセントカラー + `goalMet` を VoiceOver 値に含める）、(3) モード別カード（シャドーイング平均スクリプト一致率・瞬間英作文正解率・各サンプル数）、(4) 注記 caption（「スクリプト一致率は語の再現度であり発音の正確さではありません」「集計はこの端末内の履歴のみ」）。ロード失敗時は再試行ボタン、履歴 0 件時は空状態文言。
- `DashboardViewModel.swift`（新規, `@MainActor`）: `state: loading / ready(ProgressSummary) / empty / failed`。`load(now:)` が `attemptActivityDates()` + `attempts(from:to:)` + `loadOrCreateSettings()` を取得し、payload をデコードして `ProgressSummarizer.summarize` を呼ぶ。デコードは `static func sample(from: LessonAttemptDTO) -> ProgressSampleItem` に切り出し hostless テスト対象にする。
- Analytics イベントは追加しない（roadmap Phase 2 の Analytics 節に該当イベントがなく YAGNI。必要になれば別途）。

### 4.1 アクセシビリティ

- チャートに `accessibilityLabel`（日付）と `accessibilityValue`（「n 問、目標達成」）。
- 最大 Dynamic Type でカードが縦積みに崩れないこと（`AdaptiveStack` 再利用）。
- 率の表示は `LocalizedFormat` 経由のパーセント文字列（小数 0 桁）。

### 4.2 String Catalog（`Resources/Localizable.xcstrings`、ja のみ既存に合わせる）

`home.progress_link` / `dashboard.title` / `dashboard.streak.title` / `dashboard.streak.longest` / `dashboard.streak.total` / `dashboard.week.title` / `dashboard.week.total` / `dashboard.bar.value_label`（%1$d 問） / `dashboard.bar.goal_met` / `dashboard.modes.title` / `dashboard.modes.shadowing` / `dashboard.modes.composition` / `dashboard.modes.samples`（%1$d 件） / `dashboard.modes.no_data` / `dashboard.metric_note` / `dashboard.local_note` / `dashboard.empty` / `dashboard.load_failed` / `dashboard.retry`

## 5. テスト

- **core（Linux, 必須 green）**: `Tests/HabitKitTests/ProgressSummarizerTests.swift` — 7 日バーの埋め（0 件日・境界 04:00 跨ぎ・タイムゾーン注入）、週間合計、モード平均（shadowing 平均・composition の unscored 除外・分母 0 → nil）、goalMet 判定、窓外サンプル無視、activity と windowSamples の独立性。
- **iOS hostless（macOS CI、課金修復後）**: `Tests/AppFeatureTests/DashboardViewModelTests.swift` — DTO→サンプル写像（shadowing v1 / composition v2 / composition v1 `passed` 互換 / 未知 schemaVersion 除外 / 壊れ JSON 除外）、`load` の empty / ready 状態。`Tests/PersistenceTests/PersistenceHabitTests.swift` に `attempts(from:to:)` の範囲・順序テストを追加。
- **lint**: Linux SwiftLint strict（`no_hardcoded_ui_japanese` 含む）。

## 6. docs 同期（同一 PR 内）

- `docs/architecture.md` §2.1: HabitKit 責務に「進捗集計」、AppFeature 責務に「進捗ダッシュボード」を追記。
- `docs/ux-design.md`: §4.8「進捗ダッシュボード」を新設し、§5 状態マトリクスと §8 名前空間に追記。
- `docs/roadmap.md`: Phase 2 実装状況注記の「グラフ類のダッシュボードは未実装」を「実装済み（DoD の実機確認は未）」へ更新。残スコープ列挙から削除。

## 7. コミット順（実績はマージ後に追記）

1. `docs: ダッシュボード実装計画を追加`（本書）
2. `feat(habit): ProgressSummarizer 追加`（core + Linux テスト）
3. `feat(dashboard): 進捗ダッシュボード画面と Persistence 期間クエリ`（iOS + hostless テスト + xcstrings + docs 同期）

## 8. リスクと CI 制約

| リスク | 緩和 |
|--------|------|
| GitHub Actions 課金停止で ios-macos 検証不可 | core を Linux で全緑、SwiftLint を Linux で strict 実行。iOS 差分は既存パターンの忠実な踏襲に限定し、課金修復後（beads `ss-az4`）に CI を回してから undraft |
| Swift Charts の API 誤用（CI でしか検出できない） | `BarMark` + `chartXAxis/YAxis` の最小構成に留める。iOS 17 で利用可能な API のみ使用 |
| 大量履歴でのデコードコスト | 取得を 30 学習日窓に限定（全履歴を運ぶのは軽量な `createdAt` のみ） |
