# 全画面 UIUX 磨き込み 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SnapSpeak 全画面（オンボーディング / ホーム / 復習セッション / シャドーイング / 瞬間英作文 / ドライブモード / ダッシュボード / 設定 / カタログ / ダウンロード / プライバシー）を ui-ux-pro-max の優先度カテゴリで監査した結果を、検証可能な bite-sized タスクとして実装に落とす。

**Architecture:** 既存の MVVM + Swift Concurrency・DesignSystem 部品（`CardContainer` / `PrimaryButton` / `SecondaryButton` / `StreakBadge` / `ProgressRing` / `ScoreBadge` / `AdaptiveStack` / `DegradedBanner` / `Typography` / `Colors` / `LocalizedFormat`）を拡張して対処する。新規モジュール・新規外部依存・新規アーキテクチャは導入しない。`Packages/SnapSpeakCore` のスキーマ・採点定義は触らない（`LessonV1` への `title` 追加などの schemaVersion 変更は本計画の対象外。未知の高い schemaVersion は拒否される不変条件と衝突するため）。変更範囲は iOS パッケージ（表示・ViewModel・`ContentKit.DownloadManager` 公開 API）と `Resources/`、およびダッシュボード表示変更に伴う `docs/ux-design.md` §4.8 の同期に閉じる。

**Tech Stack:** SwiftUI / iOS 17+ / SwiftData / String Catalog（`Resources/Localizable.xcstrings`）/ Swift Charts（ダッシュボード）/ AVSpeechSynthesizer（ドライブ TTS）。

**Spec:**
- UX 正本: [ux-design.md](./ux-design.md)（§ 番号を各タスクから参照する）
- 監査基準: ui-ux-pro-max スキル（`SKILL.md` の優先度カテゴリ表 + `references/quick-reference.md` §1〜§10 + `references/pro-rules.md` の Pre-Delivery Checklist）
- 先行計画書フォーマット: [dashboard-implementation-plan.md](./dashboard-implementation-plan.md) / [quality-pass-plan.md](./quality-pass-plan.md)
- 既知指摘: beads `ss-j36`（ダッシュボードのデザインレビュー 4 件 A〜D。Phase 1 タスク群に組み込み済み）

## Global Constraints

**この節は全タスクに暗黙適用される。違反する変更はレビューで差し戻す。**

- TCA を導入しない（MVVM + Swift Concurrency を維持）。
- UI 文字列は String Catalog（`Resources/Localizable.xcstrings`）経由。コード内の日本語リテラル禁止（SwiftLint `no_hardcoded_ui_japanese` で強制）。`Text()` を通らない文言（TTS アナウンス等）は `String(localized:)` 経由をレビューで担保する。
- `AppleLanguages` を書き換えない（SwiftLint `no_apple_languages` で強制）。
- すべてのタップ領域は 44×44pt 以上（`frame(minWidth: 44, minHeight: 44)` 等）。
- Dynamic Type は最大（アクセシビリティサイズ）まで対応。固定サイズは ux-design が明示した要素（例: ダッシュボードのチャート高 180pt、ドライブの状態語）のみ。
- VoiceOver の操作順は視覚順に一致させる。装飾シンボルは `accessibilityHidden(true)`、意味を持つアイコンにはラベルを付ける。
- 色のみに依存した状態表示をしない（アイコン・テキスト・`isSelected` 等を併記）。
- Reduce Motion 対応: 新規アニメーションは `@Environment(\.accessibilityReduceMotion)` で静止表現に落とす。
- SwiftLint strict green（`file_length` 400 行。超過しそうな場合は責務で分割する）。
- core パッケージ（`Packages/SnapSpeakCore`）は Apple フレームワークを import しない。本計画では core に変更を入れない（`LessonV1` スキーマ拡張も禁止。カタログラベルは item 本文で解決する）。
- 学習履歴・`ReviewEvent` は追記型のまま。SRS カードを LWW しない。採点指標名は「スクリプト一致率 / 語の再現度」であり発音精度と誤認させない。
- 分析イベントは ux-design §9 の表と 1:1 を維持する（本計画ではイベントの追加・削除・ペイロード変更を行わない）。

## 検証戦略（全タスク共通）

1. **Linux 回帰**: `cd Packages/SnapSpeakCore && swift test` が green であること（本計画は core 非接触のため「壊していないこと」の確認）。
2. **iOS コンパイル・hostless テスト**: GitHub Actions `ios-macos` ジョブをコンパイラとして使う既存運用（AGENTS.md 参照）。iOS 側のコミットごとに CI を回し、赤なら直してから次へ進む。ロジック変更を含むタスクは hostless ユニットテスト（`Packages/SnapSpeakiOS/Tests/` の既存 target。`App/project.yml` の bundle_loader なし・製品直接リンク方式）で固定する。
3. **SwiftLint**: CI の `lint` ジョブ（strict）。Linux で手元実行する場合は `LD_LIBRARY_PATH=$HOME/.local/share/swiftly/toolchains/6.1.2/usr/lib swiftlint lint --strict`。
4. **視覚確認（コード忠実 HTML モックアップ）**: ss-j36 を生んだ前回レビューと同じ手法。SwiftUI のビュー構造・色・フォント・文言（xcstrings の ja 値）を 1:1 で写した静的 HTML を `docs/mockups/` に置き、ブラウザで目視レビューする。手順は Task 1 に集約する。モックアップはあくまでレビュー用アーティファクトであり、実装の正本は SwiftUI コードと ux-design.md。
5. **実機でしか確認できない項目**（VoiceOver 実読み上げ、Dynamic Type 最大での実レイアウト、実走行中のドライブ画面）は本計画のスコープ外とし、実装完了後にユーザー向けチェックリスト（§「実機確認に委ねる項目」）へ分離する。

---

## 監査サマリ（全指摘の一覧）

監査は ui-ux-pro-max の優先度カテゴリ順（1. Accessibility → 2. Touch & Interaction → 3. Performance → 4. Style Selection → 5. Layout & Responsive → 6. Typography & Color → 7. Animation → 8. Forms & Feedback → 9. Navigation Patterns → 10. Charts & Data）で全画面を走査し、ux-design.md との乖離を併記した。優先度: **P1** = 優先度カテゴリ 1〜2（CRITICAL）相当または ux-design 明示仕様への違反。**P2** = カテゴリ 3〜6・9（HIGH/MEDIUM）相当。**P3** = カテゴリ 7・8・10 相当または仕様の明確化。

| # | 画面 | 指摘 | 優先度 | 根拠 | 対応タスク |
|---|------|------|--------|------|-----------|
| 1 | ダッシュボード | 0 件日のバーが高さ 0 で不可視になり欠測に見える（ss-j36 A） | P1 | ss-j36 A / ux-design §4.8「0 件日も 0 のバー」/ quick-reference §10 `empty-data-state` | Task 2 |
| 2 | ダッシュボード | モード別カードの % に指標名がなく、シャドーイング=平均スクリプト一致率 / 瞬間英作文=正解率 の区別が行内で不明（ss-j36 B） | P1 | ss-j36 B / ux-design §4.8・不変条件 8（発音精度と誤認させない） | Task 3 |
| 3 | ダッシュボード | ストリーク at-risk 状態が炎アイコンの差のみでテキストがない（ホームには `streak.at_risk` 表示あり）（ss-j36 C） | P1 | ss-j36 C / ux-design §4.3・§7 / quick-reference §1 `color-not-only` | Task 4 |
| 4 | ダッシュボード | モード別平均が直近 30 学習日窓である旨の表記がない（ss-j36 D） | P1 | ss-j36 D / ux-design §4.8「直近 30 学習日」/ §6 数字は正直に | Task 5 |
| 5 | ダッシュボード | チャートの `accessibilityLabel` がカード見出しと同一キーで冗長。全体要約（`screen-reader-summary`）になっていない | P1 | quick-reference §10 `screen-reader-summary` / ux-design §4.8 a11y | Task 6 |
| 6 | ダッシュボード | 達成日の判別がアクセント色 + 値ラベルのみで、非達成日との視覚差が色依存（値ラベルは全日表示のため区別記号がない） | P1 | ux-design §4.8「色だけに依存しない」/ quick-reference §10 `pattern-texture` | Task 6 |
| 7 | シャドーイング結果 | `ResultView` が `ShadowingScore` のうち scriptMatchRate しか表示せず、ux-design / roadmap Phase 1 が求める抜け・言い淀み・WPM・遅延の結果内訳がない | P1 | roadmap Phase 1 主要機能・DoD「結果画面の主指標がスクリプト一致率と案内され…」/ ux-design §4.4 | Task 7 |
| 8 | シャドーイング / 瞬間英作文 | `.failed(String)` で `String(describing: error)` の生エラー文字列をそのまま表示。原因と回復方法を示さない | P1 | quick-reference §8 `error-clarity` / `error-recovery` / ux-design P5（劣化を隠さない・責めない） | Task 8 |
| 9 | シャドーイング / 瞬間英作文 | 録音中（`.playing` / `.recording`）にアプリ内の録音中インジケータがない | P1 | roadmap Phase 1 DoD「録音中インジケータが出る」/ quick-reference §2 `loading-buttons` | Task 9 |
| 10 | 瞬間英作文 | ヒントボタンを押しても UI 上にヒントが表示されない（`usedHint` フラグが立つだけで SRS 品質を下げるのみ。ユーザーに何も返らない） | P1 | quick-reference §2 `press-feedback` / §8 `submit-feedback`（操作に対する可視の応答がない） | Task 10 |
| 11 | オンボーディング | 2 画面間の移動に進捗インジケータがなく、複数ステップであることが分からない | P2 | quick-reference §8 `multi-step-progress` / ux-design §3.1 | Task 11 |
| 12 | オンボーディング | 目標プリセットの `.inline` Picker がラジオグループとしての意味付け（`accessibilityElement(children: .contain)` とグループラベル）を持たない | P2 | ux-design §7「目標プリセットはラジオグループとして読み上げ」 | Task 11 |
| 13 | ホーム | ドライブカードのカード本体（`buttonStyle(.plain)` のみ）に押下時の可視フィードバックがなく、タップ可能であるアフォーダンス（chevron 等）がない | P2 | quick-reference §2 `press-feedback` / §9 `nav-label-icon` | Task 12 |
| 14 | カタログ | レッスン行のラベルが `item.id`（例: `item-001`）そのままで、ユーザーに意味のある名称ではない。`LessonV1` にタイトルはなく、lesson 単位へ集約すると 2 件目以降の item をカタログから開けなくなる | P2 | quick-reference §5 `content-priority` / ux-design P2（意思決定を委ねない）/ ContentCore `LessonV1`（`title` なし・`items: [ItemV1]`） | Task 13 |
| 15 | ダウンロード | コースの表示が `course.id` で、タイトル解決（`LocalizedTitle.resolve`）を使っていない。容量の実数値もない（`downloads.storage` 固定文言のみ） | P2 | quick-reference §8 `progressive-disclosure` / roadmap Phase 2「ダウンロード管理 UI の強化（容量、削除…）」 | Task 14 |
| 16 | ダウンロード | 削除が即時実行で確認ダイアログがない（破壊的操作） | P2 | quick-reference §8 `confirmation-dialogs` / `destructive-emphasis` | Task 14 |
| 17 | 設定 | インストール ID リセットが確認なし・フィードバックなしで即時実行される | P2 | quick-reference §8 `confirmation-dialogs` / `success-feedback` | Task 15 |
| 18 | 設定 | `settings.save_failed` が赤テキストのみで再試行導線がなく、色のみ依存 | P2 | quick-reference §8 `error-recovery` / §1 `color-not-only` | Task 15 |
| 19 | 復習セッション | 進捗ヘッダが「3 / 12」のテキストのみで視覚的なプログレスバーがない | P2 | ux-design §4.4 進捗ヘッダ / quick-reference §8 `multi-step-progress` | Task 16 |
| 20 | セッションサマリ | 目標達成時の祝いが `Label` 1 行のみで、ux-design §4.5「祝いはこの画面に集約」する演出（リング完成等）がない。Reduce Motion 配慮の記述も未実装 | P2 | ux-design §4.5 / §7「達成演出」/ quick-reference §8 `success-feedback` | Task 17 |
| 21 | ホーム | 初回起動直後（`loading` 中）は habitCard ごと非表示になり、カード領域が出現する際にレイアウトシフトが起きる | P2 | quick-reference §3 `content-jumping`（CLS 相当） | Task 18 |
| 22 | ドライブ開始 | 開始画面のトップバーが自前 HStack（✕ + タイトル + 空白スペーサ）で、システムのナビゲーション構造を使っていない | P3 | quick-reference §4 `system-controls` / §9 `modal-escape` | Task 19 |
| 23 | ドライブ グランスビュー / 完了 | 状態語の固定 64pt フォントが Dynamic Type に追従しない（意図的な大型表示だが、最小スケール 0.4 で縮小されうる点は要注記） | P3 | ux-design §10.5.2（超大型タイポは仕様）/ §7 Dynamic Type 原則とのトレードオフの明文化 | Task 19（注記のみ） |
| 24 | ドライブノート | 聞き直しボタンが行内の SecondaryButton で、どの表現を再生するか VoiceOver ラベルが行テキスト依存 | P3 | quick-reference §1 `voiceover-sr` / ux-design §10.9 | Task 20 |
| 25 | プライバシー | 外部リンク（`privacy.policy`）に外部リンクである旨の明示（アイコン・a11y hint）がない | P3 | quick-reference §9 `nav-hierarchy` / §1 `aria-labels` | Task 21 |
| 26 | 復習セッション | 離脱確認が `confirmationDialog`（アクションシート）で、破壊的でない操作としてはやや重く、文言とボタン階層の対称性が弱い | P3 | ux-design §4.4「破壊的操作ではない色」/ quick-reference §8 `confirmation-dialogs` | Task 16 |
| 27 | オンボーディング | 保存失敗バナー（`onboarding.save_failed`）が赤背景のみでアイコン・再試行導線がなく、VoiceOver アナウンスもない | P2 | quick-reference §8 `error-recovery` / §1 `aria-live-errors` 相当 | Task 11 |
| 28 | ホーム | 回復カードの PrimaryButton が「今日の 1 問から再開する」で、主 CTA が画面上に 2 つ（今日の学習カードの「始める」と）並存しうる | P3 | quick-reference §4 `primary-action` / ux-design §3.4（回復カードは habitCard に置き換わる設計のため実際は排他。念のため仕様確認のみ） | 対応不要（§3.4 どおり排他表示を確認済み。監査ノートに記録） |

P1 = 10 件（#1〜#10）、P2 = 12 件（#11〜#21・#27）、P3 = 5 件対応（#22〜#26）+ #28 は確認の結果「対応不要」。

---

## Phase 1: ダッシュボード既知指摘（ss-j36 A〜D）+ チャート a11y

ss-j36 の 4 件はコード忠実モックアップによる前回デザインレビューの既知指摘であり、本計画の最初のタスク群に組み込む。

### Task 1: コード忠実 HTML モックアップの基盤とダッシュボード現状モック

**Files:**
- Create: `docs/mockups/README.md`
- Create: `docs/mockups/dashboard.html`

**Interfaces:**
- Produces: `docs/mockups/` の規約（後続タスクのモックアップが従う）。後続タスクは本タスクの README の手順でモックを更新する。

- [ ] **Step 1: モックアップ規約を書く**

`docs/mockups/README.md` に次を記す:
- 目的: iOS シミュレータを持たない環境で視覚レビューを回すため、SwiftUI コードを 1:1 で写した静的 HTML を置く（ss-j36 を生んだ前回レビューと同手法）。
- 写し方: ビュー階層（VStack/HStack/ZStack）→ flexbox、`Typography.*` → 対応する iOS システムフォントサイズ（title=28/headline=17 semibold/body=17/callout=16/caption=12）、`Colors.*` → iOS システムカラー（light/dark 両方を `prefers-color-scheme` で切替）、`CardContainer` → 角丸 16 + セカンダリ背景、文言は `Resources/Localizable.xcstrings` の ja 値を転記。
- レビュー手順: ブラウザで開き、light/dark・幅 375px（iPhone 最小相当）で確認する。指摘は beads または PR コメントに画面名つきで記録する。
- 免責: モックはレビュー用アーティファクト。正本は SwiftUI コードと ux-design.md。

- [ ] **Step 2: ダッシュボードの現状（修正前）モックを作る**

`DashboardView.swift` の `readyContent` を写す。4 カード（ストリーク / 直近 7 日 / モード別 / 注記）を縦積みで配置し、0 件日のバーが不可視になる現状（ss-j36 A）が再現するよう、サンプルデータに 0 件日を含める。

- [ ] **Step 3: Commit**

```bash
git add docs/mockups/README.md docs/mockups/dashboard.html
git commit -m "docs(mockups): コード忠実 HTML モックの規約とダッシュボード現状版を追加"
```

### Task 2: ss-j36 A — 0 件日バーの最小高さプレースホルダ

**Files:**
- Modify: `Packages/SnapSpeakiOS/Sources/AppFeature/DashboardView.swift`（`weekChart`）
- Modify: `docs/mockups/dashboard.html`

**Interfaces:**
- Consumes: `DailyProgressBar.completedItems` / `goalMet`（HabitKit。既存型・変更なし）。
- Produces: なし（表示のみの変更）。

- [ ] **Step 1: BarMark に最小高さを与える**

`weekChart` の `BarMark` を次の方針で修正する: `completedItems == 0` のバーは `y` の値を 0 のままではなく、チャート内で視認できる最小の高さ（例: `yEnd` を使った `BarMark(x:yStart:yEnd:)` で 0 → 0.15 相当の薄いバー、または `RectangleMark` のプレースホルダ）で描き、`foregroundStyle` を `Colors.secondaryFill.opacity(0.35)` にする。値ラベルの `0` は従来どおり annotation で表示する（欠測ではなく「0 件」であることが数字で読み取れる）。goalMet 日の判定・色は変更しない。

- [ ] **Step 2: VoiceOver 値を確認**

0 件日の `accessibilityValue` は既存どおり `dashboard.bar.value_label`（0 問）が読まれることをコードで確認する（変更しない）。

- [ ] **Step 3: モックアップ更新**

`docs/mockups/dashboard.html` の 0 件日バーを最小高さプレースホルダ表示に更新する。

- [ ] **Step 4: 検証**

- Linux: `cd Packages/SnapSpeakCore && swift test`（core 非接触の回帰確認）。
- iOS: `ios-macos` CI green（コンパイル確認）。

- [ ] **Step 5: Commit**

```bash
git add Packages/SnapSpeakiOS/Sources/AppFeature/DashboardView.swift docs/mockups/dashboard.html
git commit -m "fix(dashboard): 0 件日のバーに最小高さプレースホルダを表示 (ss-j36 A)"
```

### Task 3: ss-j36 B — モード別 % の指標名 caption

**Files:**
- Modify: `Packages/SnapSpeakiOS/Sources/AppFeature/DashboardView.swift`（`modeRow`）
- Modify: `Resources/Localizable.xcstrings`
- Modify: `docs/mockups/dashboard.html`

**Interfaces:**
- Produces: 新規 i18n キー `dashboard.modes.shadowing_metric` / `dashboard.modes.composition_metric`（caption 用）。

- [ ] **Step 1: i18n キーを追加**

`Resources/Localizable.xcstrings` に 2 キー追加（ja のみ。命名規約 `<画面>.<要素>[.<状態>]` に従う）:
- `dashboard.modes.shadowing_metric` = 「平均スクリプト一致率」
- `dashboard.modes.composition_metric` = 「正解率」

- [ ] **Step 2: modeRow に caption を追加**

`modeRow(titleKey:rate:sampleCount:)` に `metricKey: LocalizedStringKey` 引数を追加し、率の数値（`Typography.score`）の直下に `Text(metricKey).font(Typography.caption).foregroundStyle(Colors.secondaryFill)` を表示する。呼び出し側 2 箇所にそれぞれのキーを渡す。`no_data` 時は metric caption を出さない（データがないのに指標名だけ出すと空状態の意味が曖昧になるため）。

- [ ] **Step 3: モックアップ更新**

- [ ] **Step 4: 検証**

- SwiftLint strict（新規キーはカタログ経由のため `no_hardcoded_ui_japanese` に抵触しないこと）。
- `ios-macos` CI green。

- [ ] **Step 5: Commit**

```bash
git add Packages/SnapSpeakiOS/Sources/AppFeature/DashboardView.swift Resources/Localizable.xcstrings docs/mockups/dashboard.html
git commit -m "fix(dashboard): モード別 % に指標名 caption を追加 (ss-j36 B)"
```

### Task 4: ss-j36 C — ダッシュボードのストリーク at-risk テキスト

**Files:**
- Modify: `Packages/SnapSpeakiOS/Sources/AppFeature/DashboardView.swift`（`streakCard`）
- Modify: `docs/mockups/dashboard.html`

**Interfaces:**
- Consumes: 既存キー `streak.at_risk`（ホームと同じ文言を再利用。新規キー不要）。

- [ ] **Step 1: at-risk caption を追加**

`streakCard` の `StreakBadge` 直下に、ホーム `habitCard` と同じパターンで追加する:

```swift
if summary.streak.isAtRisk {
    Text("streak.at_risk")
        .font(Typography.caption)
        .foregroundStyle(Colors.warning)
}
```

`StreakBadge` の `accessibilityHint`（既に `streak.at_risk` を渡している）と表示テキストが一致することを確認する。

- [ ] **Step 2: モックアップ更新**

- [ ] **Step 3: 検証**

- `ios-macos` CI green。

- [ ] **Step 4: Commit**

```bash
git add Packages/SnapSpeakiOS/Sources/AppFeature/DashboardView.swift docs/mockups/dashboard.html
git commit -m "fix(dashboard): ストリーク at-risk をテキストでも表示 (ss-j36 C)"
```

### Task 5: ss-j36 D — 30 学習日窓の注記

**Files:**
- Modify: `Packages/SnapSpeakiOS/Sources/AppFeature/DashboardView.swift`（`notesCard`）
- Modify: `Resources/Localizable.xcstrings`
- Modify: `docs/ux-design.md`（§4.8 注記。caption 行数とキー一覧）
- Modify: `docs/mockups/dashboard.html`

**Interfaces:**
- Produces: 新規 i18n キー `dashboard.window_note`。ux-design §4.8 の注記仕様を 3 行に同期する。

- [ ] **Step 1: i18n キーを追加**

`dashboard.window_note` = 「モード別の平均は直近 30 学習日の集計です」。

- [ ] **Step 2: 注記カードに 1 行追加**

`notesCard` に `Text("dashboard.window_note")` を既存 2 行（`dashboard.metric_note` / `dashboard.local_note`）と同じスタイル（caption / secondaryFill）で追加する。

- [ ] **Step 3: ux-design.md を同期（正本の更新）**

注記が「caption 2 行」から「3 行」に変わるため、正本である `docs/ux-design.md` §4.8 を同一コミットで更新する:
- §4.8 のワイヤーフレームの注記カード部分に `dashboard.window_note` の 1 行を追加し、「caption 2 行」の記述を「caption 3 行」に修正する。
- §4.8 の仕様表「注記」行に `dashboard.window_note`（直近 30 学習日窓である旨）を追記する。

- [ ] **Step 4: モックアップ更新**

- [ ] **Step 5: 検証**

- `ios-macos` CI green。ux-design.md と実装が一致していること（注記が 3 行）を目視確認。

- [ ] **Step 6: Commit**

```bash
git add Packages/SnapSpeakiOS/Sources/AppFeature/DashboardView.swift Resources/Localizable.xcstrings docs/mockups/dashboard.html docs/ux-design.md
git commit -m "fix(dashboard): モード別平均の 30 学習日窓を注記 (ss-j36 D)"
```

### Task 6: ダッシュボード チャートの a11y 要約と達成日の非色依存マーク

**Files:**
- Modify: `Packages/SnapSpeakiOS/Sources/AppFeature/DashboardView.swift`（`weekCard` / `weekChart`）
- Modify: `Resources/Localizable.xcstrings`
- Modify: `docs/ux-design.md`（§4.8 a11y 行と直近 7 日の達成日仕様）
- Modify: `docs/mockups/dashboard.html`

**Interfaces:**
- Produces: 新規 i18n キーは `dashboard.week.summary_a11y` のみ（チャート全体の要約）。達成日の記号は SF Symbol を使うため新規キーは不要（既存 `dashboard.bar.goal_met` は VoiceOver 値として維持。`dashboard.bar.goal_met_mark` は作らない）。

- [ ] **Step 1: チャート全体の要約ラベル**

`weekChart` に付いている `.accessibilityLabel("dashboard.week.title")` を、カード見出しと重複しない要約に変更する。新規キー `dashboard.week.summary_a11y` = 「直近 7 日の学習完了数の棒グラフ。合計 %lld 問」を追加し、`LocalizedFormat.string("dashboard.week.summary_a11y", summary.weekCompletedItems)` を渡す。各バーの label/value（既存）は維持する。

- [ ] **Step 2: 達成日の非色依存マーク**

達成日（`goalMet`）の annotation テキストを `"\(bar.completedItems)"` から、値 + チェック記号（SF Symbol の `checkmark` を `Image(systemName:)` で併置した HStack）に変更し、色を見なくても達成日が判別できるようにする。記号は `accessibilityHidden(true)`（バーの `accessibilityValue` に既に `dashboard.bar.goal_met` が含まれるため二重読みさせない）。

- [ ] **Step 3: ux-design.md を同期（正本の更新）**

チャート全体の a11y ラベルが `dashboard.week.title` から `dashboard.week.summary_a11y` に変わるため、正本である `docs/ux-design.md` §4.8 を同一コミットで更新する:
- §4.8 の仕様表「a11y」行の「全体に `dashboard.week.title`」を「全体に `dashboard.week.summary_a11y`（合計値を含む要約）」に修正する。
- §4.8「直近 7 日」行に「達成日はアクセント色 + 値ラベル + チェック記号（色だけに依存しない）」と記号表示を明記する。

- [ ] **Step 4: モックアップ更新**

- [ ] **Step 5: 検証**

- `ios-macos` CI green。ux-design.md と実装が一致していることを目視確認。

- [ ] **Step 6: Commit**

```bash
git add Packages/SnapSpeakiOS/Sources/AppFeature/DashboardView.swift Resources/Localizable.xcstrings docs/mockups/dashboard.html docs/ux-design.md
git commit -m "fix(dashboard): チャート全体の a11y 要約と達成日の記号表示を追加"
```

---

## Phase 2: 学習フロー（シャドーイング / 瞬間英作文 / 復習セッション）

### Task 7: シャドーイング結果画面にスコア内訳を表示

**Files:**
- Modify: `Packages/SnapSpeakiOS/Sources/ShadowingFeature/ResultView.swift`
- Modify: `Resources/Localizable.xcstrings`
- Modify: `App/project.yml`（`ShadowingFeatureTests` は現状存在しない。target・scheme・直接依存を追加する）
- Modify: `Packages/SnapSpeakiOS/Package.swift`（同名 `testTarget` を追加する）
- Create: `Packages/SnapSpeakiOS/Tests/ShadowingFeatureTests/ResultBreakdownTests.swift`
- Create: `docs/mockups/shadowing_result.html`

**Interfaces:**
- Consumes: `ShadowingScore`（ScoringKit）の既存プロパティ `omissions: [AlignedSpan]` / `hesitations: Int` / `wpm: Double` / `delayMsMedian: Int?` / `delayGranularity: DelayGranularity`。core は変更しない。
- Produces: `static func omittedWordCount(_ omissions: [AlignedSpan]) -> Int`（抜け語数の算出。後続タスク・テストが利用）。新規 i18n キー `result.breakdown.omissions`（「抜け %lld 語」）/ `result.breakdown.hesitations`（「言い淀み %lld 回」）/ `result.breakdown.wpm`（「WPM %.1f」）/ `result.breakdown.delay`（「遅延 中央値 %lld ms」）/ `result.breakdown.delay_approx`（「遅延は文単位の概算です」）。

- [ ] **Step 1: i18n キーを追加**

上記 5 キーを `Resources/Localizable.xcstrings` に追加（ja のみ。件数は `%lld`、WPM は `%.1f` のまま）。

- [ ] **Step 2: 抜け語数の算出ロジックを実装する**

`score.omissions` は `[AlignedSpan]` で、各要素は連続した抜け区間（半開区間 `[startRefIndex, endRefIndex)`、ScoringKit `AlignedSpan` / `HesitationDetector` 実装どおり）。`omissions.count` は「区間数」であり「抜けた語数」ではないため、語数は次の純関数で算出する（`ResultView.swift` 内の private ヘルパか、テスト可能な static func として `ShadowingFeature` に置く）:

```swift
/// 抜けた語数 = 各区間の (endRefIndex - startRefIndex) の合計（半開区間）。
static func omittedWordCount(_ omissions: [AlignedSpan]) -> Int {
    omissions.reduce(0) { $0 + max(0, $1.endRefIndex - $1.startRefIndex) }
}
```

- [ ] **Step 3: `ShadowingFeatureTests` を新設し、抜け語数テストを追加する**

`ShadowingFeatureTests` はリポジトリに無い（`App/project.yml` の `SnapSpeakiOSTests` scheme にも、`Packages/SnapSpeakiOS/Package.swift` にも無い）。「既存 target」扱いにせず、本タスクで新設する。hostless（bundle_loader なし・製品を直接リンク）で、`CompositionFeatureTests` と同型にする。

`App/project.yml` に target を追加する（`CompositionFeatureTests` の直後）:

```yaml
  ShadowingFeatureTests:
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: ../Packages/SnapSpeakiOS/Tests/ShadowingFeatureTests
    dependencies:
      - package: SnapSpeakiOS
        product: ShadowingFeature
      - package: SnapSpeakiOS
        product: Persistence
      - package: SnapSpeakiOS
        product: SpeechKit
      - package: SnapSpeakiOS
        product: Analytics
      - package: SnapSpeakiOS
        product: AudioEngine
      - package: SnapSpeakiOS
        product: ContentKit
      - package: SnapSpeakCore
        product: ContentCore
      - package: SnapSpeakCore
        product: LanguageKit
      - package: SnapSpeakCore
        product: ScoringKit
      - package: SnapSpeakCore
        product: SRSKit
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        PRODUCT_BUNDLE_IDENTIFIER: app.snapspeak.ShadowingFeatureTests
```

scheme `SnapSpeakiOSTests` の `build.targets` に `ShadowingFeatureTests: [test]`、`test.targets` に `- ShadowingFeatureTests` を追加する（製品は直接リンク。`bundle_loader` は使わない）。

`Packages/SnapSpeakiOS/Package.swift` の `targets` に次を追加する:

```swift
.testTarget(
    name: "ShadowingFeatureTests",
    dependencies: [
        "Analytics",
        "AudioEngine",
        "ContentKit",
        "Persistence",
        "ShadowingFeature",
        "SpeechKit",
        .product(name: "ContentCore", package: "SnapSpeakCore"),
        .product(name: "LanguageKit", package: "SnapSpeakCore"),
        .product(name: "ScoringKit", package: "SnapSpeakCore"),
        .product(name: "SRSKit", package: "SnapSpeakCore"),
    ],
    swiftSettings: swift6
)
```

そのうえで `ResultBreakdownTests.swift` を作成し、次を固定する:
- 単一区間 `AlignedSpan(startRefIndex: 2, endRefIndex: 5)` → 3 語
- 複数区間 `[0..<2, 4..<7]` → 2 + 3 = 5 語
- 空配列 → 0 語
- 逆転・ゼロ長区間（`endRefIndex <= startRefIndex`）は 0 にクリップ

- [ ] **Step 4: ResultView に内訳セクションを追加**

`ScoreBadge` と `result.script_match_rate_help` の後に、内訳ブロックを追加する（抜けは Step 2 の `omittedWordCount` を使う）:

```swift
VStack(alignment: .leading, spacing: 8) {
    Text(LocalizedFormat.string("result.breakdown.omissions", Self.omittedWordCount(score.omissions)))
    Text(LocalizedFormat.string("result.breakdown.hesitations", score.hesitations))
    Text(LocalizedFormat.string("result.breakdown.wpm", score.wpm))
    if let delay = score.delayMsMedian {
        Text(LocalizedFormat.string("result.breakdown.delay", delay))
        if score.delayGranularity == .sentenceApproximate {
            Text("result.breakdown.delay_approx")
                .font(Typography.caption)
                .foregroundStyle(Colors.secondaryFill)
        }
    }
}
.font(Typography.body)
```

`DelayGranularity` のケースは ScoringKit 実装どおり `.word` / `.sentenceApproximate` / `.unavailable` を使う（`.unavailable` のときは `delayMsMedian` が nil のため遅延行自体が出ない）。指標名は「スクリプト一致率」のまま、発音精度を連想させる表現を追加しない（不変条件 8）。

- [ ] **Step 5: モックアップ作成**

`docs/mockups/shadowing_result.html` を新規作成し、内訳つき結果画面を写す。

- [ ] **Step 6: 検証**

- `ios-macos` CI green（`ShadowingFeatureTests` の抜け語数テストを含む）。`file_length`（ResultView は小さいため問題ないはず）。

- [ ] **Step 7: Commit**

```bash
git add Packages/SnapSpeakiOS/Sources/ShadowingFeature/ResultView.swift Resources/Localizable.xcstrings Packages/SnapSpeakiOS/Tests/ShadowingFeatureTests/ResultBreakdownTests.swift App/project.yml Packages/SnapSpeakiOS/Package.swift docs/mockups/shadowing_result.html
git commit -m "feat(shadowing): 結果画面に抜け・言い淀み・WPM・遅延の内訳を表示"
```

### Task 8: 生エラー文字列の表示をやめ、失敗種別ごとに原因と回復導線を示す

現状は `.failed(String)` に `String(describing: error)` を詰めて一律「読み込み失敗」相当で表示しており、録音・再生・採点の失敗を区別できない。「原因と回復方法を示す」（`error-clarity` / `error-recovery`）という目的を満たすため、失敗を型付き状態に分ける。

**Files:**
- Modify: `Packages/SnapSpeakiOS/Sources/ShadowingFeature/ShadowingLessonViewModel.swift`
- Modify: `Packages/SnapSpeakiOS/Sources/ShadowingFeature/ShadowingLessonView.swift`
- Modify: `Packages/SnapSpeakiOS/Sources/CompositionFeature/CompositionSessionViewModel.swift`
- Modify: `Packages/SnapSpeakiOS/Sources/CompositionFeature/CompositionCardView.swift`
- Modify: `Resources/Localizable.xcstrings`
- Test: `Packages/SnapSpeakiOS/Tests/ShadowingFeatureTests/`（Task 7 で `App/project.yml` / `Package.swift` に新設する target。本タスク単体で先に進める場合は Task 7 と同じ target・scheme・直接依存を先に追加する）
- Test: `Packages/SnapSpeakiOS/Tests/CompositionFeatureTests/`（既存 target に失敗種別・再試行テストを追加）

**Interfaces:**
- Consumes: 既存の `ShadowingUseCaseError` / `CompositionUseCaseError`。`microphoneDenied` は既存フェーズのまま `.failed` に落とさない。
- Produces: 各 ViewModel にネストした同型の失敗種別（`ShadowingLessonViewModel.FailureKind` / `CompositionSessionViewModel.FailureKind`。ケースは `load` / `playback` / `scoring`）。`CompositionFeature` が `ShadowingFeature` に依存しないよう、共有型は作らない。両 ViewModel の `.failed` を `failed(String)` から `failed(FailureKind)` に変える。採点失敗からの復帰は `retryAfterScoringFailure()`（シャドーイングは `.ready`、瞬間英作文は `.prompt`。採点 API は再実行しない）。新規 i18n キー `lesson.error.load`（「教材の読み込みに失敗しました。もう一度お試しください」）/ `lesson.error.playback`（「録音または再生に失敗しました。もう一度お試しください」）/ `lesson.error.scoring`（「採点に失敗しました。もう一度お試しください」）。

写像（`ShadowingLessonViewModel`）:
- `load()` の course/item 欠落 → `.failed(.load)`
- `start()` / `replayPreview()` の catch（`microphoneDenied` 以外）→ `.failed(.playback)`
- `stopAndScore()` の catch → `.failed(.scoring)`

写像（`CompositionSessionViewModel`）:
- `load()` の course/item 欠落 → `.failed(.load)`
- `startSpeaking()` の catch（`microphoneDenied` 以外。現状は `.prompt` に黙って戻る）→ `.failed(.playback)`
- `submitTyped()` / `finishSpeaking()` の catch → `.failed(.scoring)`

採点失敗の回復（再実行しない）: `ShadowingUseCase.stopAndScore` は先頭で `audio.stop()` し、その戻り値の `session.recordingURL` だけで認識する。失敗後に `stopAndScore()` を再呼びしても録音 URL は既に破棄されている。瞬間英作文も「直前が typed か spoken か」を保持していないため、`submitTyped()` / `finishSpeaking()` の再実行は経路不定で、spoken の録音 URL も消費済みになりうる。**採点失敗の再試行は採点の再実行ではなく、入力し直し（再録音 / 再入力）へ戻す。** 録音ファイルを残して採点を再実行する設計は本タスクでは採らない（破棄済み URL を復活させる変更が AudioEngine に及び、失敗録音の寿命管理が増えるため）。

- [ ] **Step 1: 失敗種別の写像テストを先に書く（失敗することを確認）**

各 ViewModel の写像表どおり、`load` / `start` / `replayPreview` / `stopAndScore` / `startSpeaking` / `submitTyped` / `finishSpeaking` が `.failed(FailureKind)` になるテストを追加する。現状は `.failed(String)` のためコンパイルエラー（= 失敗）になることを確認する。共有型 `LessonFailureKind` は作らない。

- [ ] **Step 2: 失敗種別の型と ViewModel の写像を実装**

各 ViewModel に `public enum FailureKind: Sendable, Equatable { case load, playback, scoring }` をネスト定義する。Interfaces の写像表どおり `.failed(FailureKind)` に変更し、生の `String(describing:)` は破棄する。`microphoneDenied` は既存フェーズを維持する。加えて `retryAfterScoringFailure()` を実装する（シャドーイング: `score = nil` のうえ `phase = .ready`。瞬間英作文: `outcome = nil`・`recordingURL = nil` のうえ `phase = .prompt`。`stopAndScore` / `submitTyped` / `finishSpeaking` は呼ばない）。

- [ ] **Step 3: テストが通ることを確認（hostless は CI）**

- [ ] **Step 4: i18n キーを追加**

Interfaces の 3 キー（`lesson.error.load` / `lesson.error.playback` / `lesson.error.scoring`）を追加する。既存の `common.error` / `common.retry` はそのまま使う。一律の `common.error_load_failed` は使わない。

- [ ] **Step 5: 両ビューの failed 表示を種別ごとに修正**

`ShadowingLessonView` / `CompositionCardView` で、`.failed(let kind)` を switch し、種別に対応する本文キー（`lesson.error.load` / `lesson.error.playback` / `lesson.error.scoring`）を表示する。生エラー文字列は表示しない。回復導線は種別に応じて:
- `.load` → `common.retry` で `load()` 再試行
- `.playback` → シャドーイングは `start()`、瞬間英作文は `startSpeaking()`（録音・再生のやり直し）
- `.scoring` → **採点を再実行しない。** 各 ViewModel に `retryAfterScoringFailure()` を追加する。
  - シャドーイング: `score = nil` にして `phase = .ready` に戻す。再試行ボタンはこのメソッドだけを呼び、ユーザーは既存の開始操作で**再録音**する。
  - 瞬間英作文: `outcome = nil`、`recordingURL = nil` にして `phase = .prompt` に戻す。`typedText` は残してよく、ユーザーがキーボード再送信またはマイクから**再入力 / 再録音**する。
  - テストで固定する: 採点失敗後の retry が `stopAndScore` / `submitTyped` / `finishSpeaking` を呼ばないこと、および `phase` が `.ready` / `.prompt` になること。

- [ ] **Step 6: 検証**

- `ios-macos` CI green。生エラー文字列が UI に出ないことを `rg "Text\\(message\\)|String\\(describing:" Packages/SnapSpeakiOS/Sources` が UI 表示経路で 0 件になることで確認。

- [ ] **Step 7: Commit**

```bash
git add Packages/SnapSpeakiOS/Sources/ShadowingFeature/ Packages/SnapSpeakiOS/Sources/CompositionFeature/ Resources/Localizable.xcstrings Packages/SnapSpeakiOS/Tests/ShadowingFeatureTests/ Packages/SnapSpeakiOS/Tests/CompositionFeatureTests/
git commit -m "fix(lesson): 失敗を型付き状態に分け、種別ごとの原因と回復導線を表示"
```

Task 7 より先に本タスクだけを実装する場合は、同じコミットに `App/project.yml` と `Packages/SnapSpeakiOS/Package.swift` の `ShadowingFeatureTests` 新設（Task 7 Step 3 と同じ定義）を含める。

### Task 9: 録音中インジケータ

**Files:**
- Modify: `Packages/SnapSpeakiOS/Sources/ShadowingFeature/ShadowingLessonView.swift`
- Modify: `Packages/SnapSpeakiOS/Sources/CompositionFeature/CompositionCardView.swift`
- Modify: `Resources/Localizable.xcstrings`

**Interfaces:**
- Produces: 新規 i18n キー `recording.indicator`（「録音中」）。

- [ ] **Step 1: i18n キーを追加**

`recording.indicator` = 「録音中」。

- [ ] **Step 2: 録音中バッジを追加**

シャドーイングは `case .playing`、瞬間英作文は `case .recording` のとき、コントロールの直上に次を表示する:

```swift
Label("recording.indicator", systemImage: "record.circle.fill")
    .font(Typography.callout)
    .foregroundStyle(Colors.danger)
```

シンボル + テキスト併記で色のみ依存にしない。OS のマイクインジケータ（ステータスバー）とは別に、アプリ内でも録音状態を明示する（roadmap Phase 1 DoD「録音中インジケータが出る」）。

- [ ] **Step 3: 検証**

- `ios-macos` CI green。

- [ ] **Step 4: Commit**

```bash
git add Packages/SnapSpeakiOS/Sources/ShadowingFeature/ShadowingLessonView.swift Packages/SnapSpeakiOS/Sources/CompositionFeature/CompositionCardView.swift Resources/Localizable.xcstrings
git commit -m "feat(lesson): 録音中インジケータを表示"
```

### Task 10: 瞬間英作文のヒント表示

**Files:**
- Modify: `Packages/SnapSpeakiOS/Sources/CompositionFeature/CompositionSessionViewModel.swift`
- Modify: `Packages/SnapSpeakiOS/Sources/CompositionFeature/CompositionCardView.swift`
- Modify: `Resources/Localizable.xcstrings`
- Modify: `Packages/SnapSpeakiOS/Tests/CompositionFeatureTests/`（既存 target にテスト追加）

**Interfaces:**
- Consumes: `ItemV1.sentencePair?.acceptable`（先頭の許容パターンの**最初の 1 語**をヒントとして使う。ContentCore 既存型）。
- Produces: `CompositionSessionViewModel.hintText: String?`（`@Published private(set)`）。`revealHint()` が `usedHint = true` に加えて `hintText` をセットする。新規 i18n キー `composition.hint_label`（「ヒント」）。

正本との整合: product-overview.md §234-242「ヒント: MVP は『最初の 1 語を表示』」に従い、**許容文の全文ではなく最初の 1 語のみ**を表示する（答えの開示にならないようにするため）。

- [ ] **Step 1: 失敗するテストを書く**

`CompositionFeatureTests` に「`revealHint()` を呼ぶと `usedHint == true` かつ `hintText` が acceptable 先頭文の**最初の 1 語**になる」「`acceptable` が空、または先頭文が空文字なら `hintText` は nil のまま」を追加し、現状（`hintText` 未定義）でコンパイルエラーになることを確認する。最初の 1 語の切り出しは空白区切り（L2 は英語のため `split(separator: " ").first` で足りる）をテストで固定する。

- [ ] **Step 2: ViewModel に hintText を実装**

```swift
@Published public private(set) var hintText: String?

public func revealHint() {
    usedHint = true
    guard let first = item?.sentencePair?.acceptable.first, !first.isEmpty else {
        hintText = nil
        return
    }
    hintText = first.split(separator: " ").first.map(String.init)
}
```

`item` は既存の private プロパティを使う。`acceptable` は ContentCore `SentencePairV1` で `[String]`（非 Optional）のため、`item?.sentencePair?.acceptable.first` で先頭文を取り、さらに空白で分割して最初の 1 語だけを `hintText` に入れる（全文は入れない）。

- [ ] **Step 3: テストが通ることを確認（hostless は CI）**

ローカルではコンパイルできないため、`ios-macos` CI で `CompositionFeatureTests` が green になることを確認する。

- [ ] **Step 4: カードにヒントを表示**

`CompositionCardView` の `.prompt` フェーズで、`hintText` が非 nil ならヒントボタンの直下に表示する:

```swift
if let hint = viewModel.hintText {
    LabeledContent {
        Text(hint)
    } label: {
        Text("composition.hint_label")
    }
    .font(Typography.body)
}
```

- [ ] **Step 5: Commit**

```bash
git add Packages/SnapSpeakiOS/Sources/CompositionFeature/CompositionSessionViewModel.swift Packages/SnapSpeakiOS/Sources/CompositionFeature/CompositionCardView.swift Resources/Localizable.xcstrings Packages/SnapSpeakiOS/Tests/CompositionFeatureTests/
git commit -m "fix(composition): ヒントボタンで先頭の許容パターンの最初の 1 語を表示"
```

### Task 11: オンボーディングの進捗・ラジオグループ a11y・保存失敗バナー改善

**Files:**
- Modify: `Packages/SnapSpeakiOS/Sources/OnboardingFeature/OnboardingFlowView.swift`
- Modify: `Packages/SnapSpeakiOS/Sources/OnboardingFeature/OnboardingGoalView.swift`
- Modify: `Resources/Localizable.xcstrings`
- Create: `docs/mockups/onboarding.html`

**Interfaces:**
- Produces: 新規 i18n キー `onboarding.step`（「%1$lld / %2$lld」）/ `onboarding.goal.group_label`（「1 日の目標」）。

- [ ] **Step 1: ステップインジケータ**

`OnboardingFlowView` の `Group` の上に、現在ステップを示す小さなインジケータを追加する。実装は `Text(LocalizedFormat.string("onboarding.step", stepNumber, 2))`（caption / secondaryFill）+ 2 つの `Circle()`（選択中は accent、非選択は secondaryFill、各 8pt、`accessibilityHidden(true)`）の HStack。`stepNumber` は `viewModel.step == .welcome ? 1 : 2`。色のみ依存にしないため数字テキストを併記する。

- [ ] **Step 2: 目標プリセットをラジオグループとして読み上げ**

`OnboardingGoalView` の `.inline` Picker に `.accessibilityElement(children: .contain)` と `.accessibilityLabel("onboarding.goal.group_label")` を付け、ラジオグループであることを VoiceOver に伝える（ux-design §7）。

- [ ] **Step 3: 保存失敗バナーの改善**

`OnboardingFlowView` の `saveFailed` バナーに `Image(systemName: "exclamationmark.triangle.fill")`（`accessibilityHidden(true)`）を併置し、`.onChange(of: viewModel.saveFailed)` で `UIAccessibility.post(notification: .announcement, argument: ...)` を使って失敗を読み上げる（`onboarding.save_failed` の文言を `String(localized:)` で解決して渡す）。再試行は既存の主ボタン再タップで可能なため、バナー自体にボタンは追加しない。

- [ ] **Step 4: モックアップ作成**

`docs/mockups/onboarding.html` に welcome / goal の 2 画面を写す。

- [ ] **Step 5: 検証**

- `ios-macos` CI green（`OnboardingFeatureTests` 既存テストの回帰確認）。

- [ ] **Step 6: Commit**

```bash
git add Packages/SnapSpeakiOS/Sources/OnboardingFeature/ Resources/Localizable.xcstrings docs/mockups/onboarding.html
git commit -m "fix(onboarding): ステップ表示・ラジオグループ a11y・保存失敗バナー改善"
```

---

## Phase 3: ホーム / カタログ / 設定 / ドライブ / その他画面

### Task 12: ホーム ドライブカードのアフォーダンスと押下フィードバック

**Files:**
- Modify: `Packages/SnapSpeakiOS/Sources/AppFeature/HomeView.swift`（`driveCard`）
- Create: `docs/mockups/home.html`

**Interfaces:**
- Produces: なし（表示のみ）。

- [ ] **Step 1: カード本体に chevron と押下スタイルを追加**

`driveCard` の `Button(action: onOpenDrive)` のラベルに `Image(systemName: "chevron.right")`（`foregroundStyle(Colors.secondaryFill)`、`accessibilityHidden(true)`）を右端に配置し、タップ可能であることを示す。`buttonStyle(.plain)` のままだと押下フィードバックがないため、カード本体用の小さな `ButtonStyle`（押下時 `opacity(0.7)`。レイアウトは変えない）を `HomeView.swift` 内の private struct として定義して適用する（pro-rules「Stable Interaction States」に従い transform は使わない）。

- [ ] **Step 2: ホームのモックアップ作成**

`docs/mockups/home.html` に habitCard / progressLink / todayCard / driveCard / continueCard を写す（at-risk・回復カードの 2 バリアントも併記）。

- [ ] **Step 3: 検証**

- `ios-macos` CI green。

- [ ] **Step 4: Commit**

```bash
git add Packages/SnapSpeakiOS/Sources/AppFeature/HomeView.swift docs/mockups/home.html
git commit -m "fix(home): ドライブカードにタップアフォーダンスと押下フィードバックを追加"
```

### Task 13: カタログの各行を意味のある名称に（各 item 導線は維持）

**Files:**
- Modify: `Packages/SnapSpeakiOS/Sources/AppFeature/CatalogView.swift`
- Create: `docs/mockups/catalog.html`

**Interfaces:**
- Consumes: `CourseV1` / `UnitV1` / `LessonV1` / `ItemV1` の既存プロパティ（ContentCore）。`LessonV1` には `title` 辞書が**ない**（`id` / `mode` / `items` のみ。ContentCore `CourseV1.swift` で確認済み）。core は変更しない。
- Produces: なし（表示のみの変更）。

設計判断（Critical 指摘への対応）: lesson 単位への集約は**行わない**。`LessonV1` にタイトルがなく `lesson.id` フォールバックは内部 ID のままであり、かつ集約すると 2 件目以降の item をカタログから直接開けなくなるため。本タスクは **各 item 導線を維持したまま**、行の表示を `item.id` の生表示から意味のある内容に変える。スキーマ変更（`LessonV1` へのタイトル追加）は本計画のスコープ外とし、必要なら別途コンテンツスキーマの版管理（architecture の複数 immutable release 方針）に従って正式に起票する。

- [ ] **Step 1: 各行のラベルを item の本文に変更（導線は item 単位のまま）**

現状は `lesson.items` の各 `item.id` を 1 行ずつ `Label(item.id, ...)` で出している。各行の遷移先（`LessonCoordinate(courseId:lessonId:itemId:mode:)`）は**変更せず**、表示だけを次に変える:
- シャドーイング（`item.passage?.text`）→ 本文の先頭部分（例: 先頭 40 文字で打ち切り `…`）
- 瞬間英作文（`item.sentencePair?.l1`）→ L1 文（日本語プロンプト）
- どちらも取得できない場合のみ `item.id` にフォールバック

行の構成は `VStack(alignment: .leading)` で「本文（headline）」+ サブ行（caption / secondaryFill）に**ローカライズ済みモード名**を出す。モード名は既存キーを使う（`lesson.mode == .shadowing` なら `shadowing.title`＝「シャドーイング」、`.composition` なら `composition.title`＝「瞬間英作文」）。既存のモードアイコンは維持する。サブ行に `lesson.id` / `item.id` などの内部値は出さない。これにより内部 ID の生表示をやめつつ、各 item への導線はすべて維持する。

- [ ] **Step 2: モックアップ作成**

`docs/mockups/catalog.html` に、本文表示になった行（複数 item が並ぶ状態）を写す。

- [ ] **Step 3: 検証**

- `ios-macos` CI green。各行が従来どおり該当 item のレッスンへ遷移すること（遷移先の `LessonCoordinate` 生成ロジックを変更していないことをコードで確認）。

- [ ] **Step 4: Commit**

```bash
git add Packages/SnapSpeakiOS/Sources/AppFeature/CatalogView.swift docs/mockups/catalog.html
git commit -m "fix(catalog): 各行を item.id 生表示から本文表示に変更（各 item 導線は維持）"
```

### Task 14: ダウンロード管理のタイトル表示・容量・削除確認

**Files:**
- Modify: `Packages/SnapSpeakiOS/Sources/AppFeature/DownloadsView.swift`（`import ContentCore` を追加し、`LocalizedTitle.resolve` を呼ぶ）
- Modify: `Packages/SnapSpeakiOS/Sources/ContentKit/DownloadManager.swift`（容量の公開 API 追加）
- Modify: `Resources/Localizable.xcstrings`
- Test: `Packages/SnapSpeakiOS/Tests/ContentKitTests/DownloadManagerSizeTests.swift`（既存 target に追加）
- Create: `docs/mockups/downloads.html`

**Interfaces:**
- Consumes: `LocalizedTitle.resolve`（**ContentCore** `LocalizedTitle.swift`。ContentKit ではない）。`DownloadsView.swift` は現状 `import ContentKit` のみなので、`import ContentCore` を追加する。容量は既存の `DownloadManager` に公開 API を**追加**して取得する（既存 API には公開サイズ取得がなく、private の `directorySize(_:)` のみ存在する。ContentKit `DownloadManager.swift` で確認済み）。
- Produces: `DownloadManager.courseSizeOnDisk(courseId: String) -> Int64`（公開。指定コースのディレクトリ配下の合計バイト数。存在しない場合は 0）。新規 i18n キー `downloads.delete_confirm_title`（「このコースを削除しますか？」）/ `downloads.delete_confirm_message`（「ダウンロード済みの音声と教材を端末から削除します。学習履歴は残ります。」）/ `downloads.delete_confirm`（「削除」）/ `downloads.size_format`（容量の表示書式が必要な場合。`ByteCountFormatter` を使うならキー不要）。

設計判断（Important 指摘への対応）: 容量表示を「取得可能なら」の任意扱いにしない。監査指摘 #15 と roadmap Phase 2「ダウンロード管理 UI の強化（容量、削除…）」を未解消にしないため、`DownloadManager` に公開 API を追加して必ず表示する。

- [ ] **Step 1: 容量 API の失敗するテストを書く**

`ContentKitTests` に `DownloadManagerSizeTests.swift` を追加し、「既知のファイルを持つコースディレクトリの合計バイト数を返す」「存在しない courseId は 0 を返す」「`tmp-` プレフィクスの staging ディレクトリは含めない」を固定する。現状は公開 API がないためコンパイルエラー（= 失敗）になることを確認する。

- [ ] **Step 2: DownloadManager に公開 API を追加**

既存の private `directorySize(_:)` を再利用し、次を公開する:

```swift
/// 指定コースのディスク上の合計バイト数（存在しない場合は 0）。
public func courseSizeOnDisk(courseId: String) -> Int64 {
    let directory = contentRoot.appendingPathComponent(courseId, isDirectory: true)
    guard fileManager.fileExists(atPath: directory.path) else { return 0 }
    return directorySize(directory) ?? 0
}
```

- [ ] **Step 3: テストが通ることを確認（hostless は CI）**

- [ ] **Step 4: タイトル解決**

`Text(stored.course.id)` を、CatalogView と同じ解決順・同じ引数で次に置き換える（`LocalizedTitle` は ContentCore。フォールバック順は requested → sourceLanguage → `"en"`）:

```swift
LocalizedTitle.resolve(
    stored.course.title,
    requested: stored.course.languagePair.sourceLanguage,
    sourceLanguage: stored.course.languagePair.sourceLanguage
) ?? stored.course.id
```

- [ ] **Step 5: 削除確認ダイアログ**

削除ボタンの `action` で即削除せず、`@State private var pendingDelete: StoredCourse?` を立てて `.confirmationDialog` を表示する。`Button("downloads.delete_confirm", role: .destructive)` で削除実行、`Button("common.close", role: .cancel)` でキャンセル。破壊的操作は赤（`role: .destructive`）で主操作と分離する（`destructive-emphasis`）。

- [ ] **Step 6: 容量表示**

`downloads.storage` の固定文言の横に、Step 2 の `courseSizeOnDisk` で取得した実数値を `ByteCountFormatter`（`countStyle = .file`）で人間可読にして表示する（caption / secondaryFill）。容量は `dependencies.downloads`（`DownloadManager`）から非同期で取得し、行の表示時に lazy に解決する。

- [ ] **Step 7: モックアップ作成**

- [ ] **Step 8: 検証**

- `ios-macos` CI green（`ContentKitTests` の容量 API テストを含む）。

- [ ] **Step 9: Commit**

```bash
git add Packages/SnapSpeakiOS/Sources/AppFeature/DownloadsView.swift Packages/SnapSpeakiOS/Sources/ContentKit/DownloadManager.swift Resources/Localizable.xcstrings Packages/SnapSpeakiOS/Tests/ContentKitTests/ docs/mockups/downloads.html
git commit -m "fix(downloads): タイトル解決・容量表示（公開 API 追加）・削除確認ダイアログ"
```

### Task 15: 設定のインストール ID リセット確認と保存失敗の回復導線

**Files:**
- Modify: `Packages/SnapSpeakiOS/Sources/AppFeature/SettingsView.swift`
- Modify: `Resources/Localizable.xcstrings`
- Create: `docs/mockups/settings.html`

**Interfaces:**
- Produces: 新規 i18n キー `settings.reset_confirm_title`（「インストール ID をリセットしますか？」）/ `settings.reset_confirm_message`（「分析上の識別子が新しくなります。学習履歴は変わりません。」）/ `settings.reset_confirm`（「リセット」）/ `settings.reset_done`（「リセットしました」）。

- [ ] **Step 1: リセット確認ダイアログ**

`settings.reset_install_id` ボタンで即リセットせず、`@State private var confirmReset = false` を立てて `.confirmationDialog` を表示し、`role: .destructive` の確認ボタンで実行する。実行後は `settings.reset_done` を caption で一時表示する（`success-feedback`。トースト機構は既存にないため、caption 表示 + 数秒後に消す簡易実装でよい）。

- [ ] **Step 2: 保存失敗の回復導線**

`settings.save_failed` の caption に `Image(systemName: "exclamationmark.triangle.fill")`（`accessibilityHidden(true)`）を併置して色のみ依存を解消し、直下に `Button("common.retry") { Task { await persistHabitSettings() } }`（minHeight 44）を追加する。

- [ ] **Step 3: モックアップ作成**

- [ ] **Step 4: 検証**

- `ios-macos` CI green。

- [ ] **Step 5: Commit**

```bash
git add Packages/SnapSpeakiOS/Sources/AppFeature/SettingsView.swift Resources/Localizable.xcstrings docs/mockups/settings.html
git commit -m "fix(settings): インストール ID リセットの確認と保存失敗の再試行導線を追加"
```

### Task 16: 復習セッションのプログレスバーと離脱確認の階層整理

**Files:**
- Modify: `Packages/SnapSpeakiOS/Sources/ReviewFeature/ReviewSessionView.swift`
- Modify: `Resources/Localizable.xcstrings`
- Create: `docs/mockups/review_session.html`

**Interfaces:**
- Consumes: 既存の `running(index:total:)` フェーズ。ViewModel は変更しない。

- [ ] **Step 1: プログレスバーを追加**

`runningBody` の進捗テキスト（「3 / 12」）の直下に `ProgressView(value: Double(index + 1), total: Double(total))` を追加し、`.tint(Colors.accent)` を適用する。テキストは残す（色・バーのみ依存にしない）。VoiceOver は既存の `review.session.progress_a11y` アナウンスを維持し、プログレスバー自体は `accessibilityHidden(true)`（二重読み防止）。

- [ ] **Step 2: 離脱確認のキャンセル文言を「閉じる」から「キャンセル」に修正**

現状の `confirmationDialog` はキャンセルに `common.close`（「閉じる」）を使っており、離脱確認の文脈では「閉じる」が「離脱する」と読み違えられうる（対称性が弱いという監査指摘 #26）。キャンセル専用のキー `common.cancel`（「キャンセル」）を新規追加し、キャンセルボタンを `Button("common.cancel", role: .cancel)` に変更する。`review.session.leave_confirm` ボタンには `role` を付けない（破壊的ではない。ux-design §4.4「破壊的操作ではない色」）。タイトル・メッセージは既存キーのまま変更しない。

- [ ] **Step 3: モックアップ作成**

- [ ] **Step 4: 検証**

- `ios-macos` CI green（`ReviewFeatureTests` 回帰）。`common.cancel` が `Resources/Localizable.xcstrings` に追加されていること。

- [ ] **Step 5: Commit**

```bash
git add Packages/SnapSpeakiOS/Sources/ReviewFeature/ReviewSessionView.swift Resources/Localizable.xcstrings docs/mockups/review_session.html
git commit -m "fix(review): セッションにプログレスバーを追加し離脱確認のキャンセル文言を修正"
```

### Task 17: セッションサマリの達成演出（Reduce Motion 対応）

**Files:**
- Modify: `Packages/SnapSpeakiOS/Sources/ReviewFeature/ReviewSummaryView.swift`
- Create: `docs/mockups/review_summary.html`

**Interfaces:**
- Consumes: 既存 `didMeetGoal: Bool` / `completedItemsAfter` / `goalItems` / `completedCount`。`ProgressRing`（DesignSystem。`progress: Double` を受け取って描画するだけなので、アニメーション用の値は View 側の `@State` で持つ）。
- Produces: なし（表示のみ。新規 i18n キーは作らない。a11y 値は既存 `home.goal.progress`）。

- [ ] **Step 1: 達成時のリング演出（`@State` で 0 → 1 の状態変化を作る）**

`progress: 1` を渡したまま `withAnimation` しても開始値が 1 のままなので状態変化が起きない。リング進捗は View の `@State` にし、表示開始時に 0 から 1 へ更新する。

```swift
@State private var ringProgress: Double = 0
@Environment(\.accessibilityReduceMotion) private var reduceMotion

private var goalRingValueText: String {
    LocalizedFormat.string(
        "home.goal.progress",
        completedItemsAfter ?? completedCount,
        goalItems ?? max(completedItemsAfter ?? completedCount, 1)
    )
}

private func startGoalRingIfNeeded() {
    guard didMeetGoal else { return }
    if reduceMotion {
        ringProgress = 1
        return
    }
    ringProgress = 0
    withAnimation(.easeOut(duration: 0.6)) {
        ringProgress = 1
    }
}
```

`didMeetGoal == true` のとき、`Label("review.summary.goal_met", ...)` の直上に次を中央配置する（達成 = チェック入りリングの既存表現を再利用）:

```swift
ProgressRing(
    progress: ringProgress,
    accessibilityLabel: "home.goal.ring_label",
    accessibilityValueText: goalRingValueText
)
.onAppear(perform: startGoalRingIfNeeded)
```

開始・リセット: `onAppear` のたびに `startGoalRingIfNeeded()` を呼ぶ。Reduce Motion OFF では毎回 `ringProgress = 0` に戻してから 1 へアニメーションする（再表示で再生される）。Reduce Motion ON では最初から `ringProgress = 1` の静止表示（ux-design §7「Reduce Motion で静止画に差し替え。音は鳴らさない」）。アニメーション中も入力はブロックしない（`no-blocking-animation`）。`accessibilityValueText` はプレースホルダにせず、既存キー `home.goal.progress`（「今日 %1$lld / %2$lld 問」）に `completedItemsAfter ?? completedCount` と `goalItems ?? max(completedItemsAfter ?? completedCount, 1)` を渡した文字列にする。

- [ ] **Step 2: モックアップ作成**

- [ ] **Step 3: 検証**

- `ios-macos` CI green。

- [ ] **Step 4: Commit**

```bash
git add Packages/SnapSpeakiOS/Sources/ReviewFeature/ReviewSummaryView.swift docs/mockups/review_summary.html
git commit -m "feat(review): サマリの目標達成にリング演出（Reduce Motion 対応）"
```

### Task 18: ホーム habitCard のレイアウトシフト防止

**Files:**
- Modify: `Packages/SnapSpeakiOS/Sources/AppFeature/HomeView.swift`（`habitCard`）

**Interfaces:**
- Produces: なし。

- [ ] **Step 1: loading 中のプレースホルダ（`TodayState.loading` に限定）**

`habitCard` は現在 `if let snapshot = today.snapshot` で、nil の間はカードごと消える。ただし `snapshot == nil` をすべて loading と扱うと、**初回読み込み失敗（`TodayState.failed`）でもプレースホルダが残ってしまう**（Important 指摘）。プレースホルダは `today.state == .loading` のときに限定する:

```swift
if let snapshot = today.snapshot {
    // 既存の habitCard 本体
} else if today.state == .loading {
    // プレースホルダ（下記）
}
// .failed / .empty / .recovery で snapshot が nil のときはプレースホルダを出さない
// （.failed は todayCard 側の load_failed + retry が既に表示される）
```

loading 中は同じ `CardContainer` 内に `StreakBadge` 相当の高さと `ProgressRing` の枠（`Colors.secondaryFill.opacity(0.25)` の円）を持つプレースホルダを表示して、出現時のレイアウトシフトを防ぐ（`content-jumping`）。プレースホルダは `accessibilityHidden(true)`（読み上げは既存の ProgressView に任せる）。

- [ ] **Step 2: 検証**

- `ios-macos` CI green。モックは Task 12 の `home.html` に loading バリアントを追記。

- [ ] **Step 3: Commit**

```bash
git add Packages/SnapSpeakiOS/Sources/AppFeature/HomeView.swift docs/mockups/home.html
git commit -m "fix(home): habitCard の loading 中プレースホルダでレイアウトシフトを防止"
```

### Task 19: ドライブ開始画面の構造整理 + グランスビュー注記

**Files:**
- Modify: `Packages/SnapSpeakiOS/Sources/DriveModeFeature/DriveStartView.swift`
- Modify: `Packages/SnapSpeakiOS/Sources/DriveModeFeature/DriveGlanceView.swift`
- Modify: `Packages/SnapSpeakiOS/Sources/DriveModeFeature/DriveSessionView.swift`（`.idle` ケースを NavigationStack で包む）
- Create: `docs/mockups/drive.html`

**Interfaces:**
- Produces: 新規 i18n キーはなし（既存キーのみ使用）。

- [ ] **Step 1: 開始画面を NavigationStack のタイトルに寄せる**

`DriveStartView` の自前 HStack（✕ + `drive.start.title` + 空白スペーサ）をやめ、`DriveSessionView` の `.idle` ケースを `NavigationStack` で包み、`.navigationTitle("drive.start.title")` + `.navigationBarTitleDisplayMode(.inline)` + toolbar の `.cancellationAction` に ✕ ボタン（`common.close` の accessibilityLabel）を置く。システムのナビゲーション構造に乗せる（`system-controls` / `modal-escape`）。

- [ ] **Step 2: グランスビューの状態語に注記コメント**

`DriveGlanceView` の固定 64pt フォントは ux-design §10.5.2 の明示仕様（超大型タイポ・1 情報）であることをコードコメントで明記し、Dynamic Type 非追従は意図的であることをレビューで再確認しやすくする（挙動は変更しない）。

- [ ] **Step 3: モックアップ作成**

`docs/mockups/drive.html` に開始画面 / グランスビュー / 完了画面 / ドライブノートを写す。

- [ ] **Step 4: 検証**

- `ios-macos` CI green（`DriveModeFeatureTests` 回帰）。

- [ ] **Step 5: Commit**

```bash
git add Packages/SnapSpeakiOS/Sources/DriveModeFeature/DriveStartView.swift Packages/SnapSpeakiOS/Sources/DriveModeFeature/DriveGlanceView.swift Packages/SnapSpeakiOS/Sources/DriveModeFeature/DriveSessionView.swift docs/mockups/drive.html
git commit -m "fix(drive): 開始画面をシステムのナビゲーション構造に寄せる"
```

### Task 20: ドライブノートの聞き直しボタン a11y

**Files:**
- Modify: `Packages/SnapSpeakiOS/Sources/DriveModeFeature/DriveNoteView.swift`
- Modify: `Resources/Localizable.xcstrings`

**Interfaces:**
- Produces: 新規 i18n キー `drive.note.replay_a11y`（「この表現を聞き直す」）。

- [ ] **Step 1: 行ごとの聞き直しラベル**

`rowCard` の `SecondaryButton("drive.note.replay")` に `.accessibilityLabel(Text(row.l2Text) + Text("drive.note.replay_a11y"))` 相当のラベルを付け、どの表現を再生するかが VoiceOver で分かるようにする。SwiftUI の文字列結合が難しければ、`.accessibilityLabel(LocalizedFormat.string("drive.note.replay_a11y"))` + `.accessibilityHint(Text(row.l2Text))` の組合せでもよい（実装時にコンパイルが通る形を選ぶ）。

- [ ] **Step 2: 検証**

- `ios-macos` CI green。

- [ ] **Step 3: Commit**

```bash
git add Packages/SnapSpeakiOS/Sources/DriveModeFeature/DriveNoteView.swift Resources/Localizable.xcstrings
git commit -m "fix(drive): ノートの聞き直しボタンに行固有の a11y ラベルを追加"
```

### Task 21: プライバシー画面の外部リンク明示

**Files:**
- Modify: `Packages/SnapSpeakiOS/Sources/AppFeature/PrivacyView.swift`
- Modify: `Resources/Localizable.xcstrings`
- Create: `docs/mockups/privacy.html`

**Interfaces:**
- Produces: 新規 i18n キー `privacy.policy_external_hint`（「外部サイトを開きます」）。

- [ ] **Step 1: 外部リンクの明示**

`Link("privacy.policy", ...)` に `Image(systemName: "arrow.up.right.square")`（`accessibilityHidden(true)`）を併置し、`.accessibilityHint("privacy.policy_external_hint")` を付ける。

- [ ] **Step 2: モックアップ作成**

- [ ] **Step 3: 検証**

- `ios-macos` CI green。

- [ ] **Step 4: Commit**

```bash
git add Packages/SnapSpeakiOS/Sources/AppFeature/PrivacyView.swift Resources/Localizable.xcstrings docs/mockups/privacy.html
git commit -m "fix(privacy): プライバシーポリシーが外部リンクであることを明示"
```

---

## 実機確認に委ねる項目（本計画のスコープ外）

実装完了後、ユーザーに実機確認を依頼する項目（quality-pass-plan §5.2 と同じ分離方針）:

- VoiceOver の実読み上げ順（オンボーディング 2 画面、ダッシュボードのチャート、ドライブノートの行）。
- Dynamic Type 最大（アクセシビリティサイズ）でのホーム / サマリ / ダッシュボードのカード崩れ有無。
- Reduce Motion ON でのサマリ達成リングが静止表示になること。
- ドライブモードの実走行でのグランスビュー視認性（状態語の大きさ・コントラスト）。
- ダークモードでの全画面コントラスト（pro-rules「Light/Dark Mode Contrast」の実機確認）。

## リスクと対応

| リスク | 影響 | 対応 |
|--------|------|------|
| iOS 側のコンパイルエラーを Linux で検出できない | 手戻り | タスクごとに `ios-macos` CI を回す既存運用。表示のみの変更を優先する。ViewModel / API / テスト target の変更は Task 7（抜け語数ヘルパと `ShadowingFeatureTests` 新設）・Task 8（失敗種別と採点失敗時の再録音復帰）・Task 10（ヒント 1 語）・Task 14（容量 API） |
| `DelayGranularity` / `acceptable` / `AlignedSpan` 等の型名の取り違え | コンパイルエラー | 計画のコード例は ScoringKit / ContentCore の実在の定義（`.sentenceApproximate` / `[String]` / 半開区間 `[startRefIndex, endRefIndex)`）に合わせ済み。実装時は改めて定義を確認する |
| 新規 i18n キーの命名が既存規約と衝突 | レビュー差し戻し | ux-design §8 の `<画面>.<要素>[.<状態>]` 規約に従う。件数は `%lld` 変数のまま |
| モックアップと実装の乖離 | レビュー誤認 | モックはコードから起こす。乖離を見つけたらモックを直す（モックが正本にならない） |
| `file_length` 400 行超過 | SwiftLint エラー | DashboardView.swift / SettingsView.swift の変更が大きくなる場合は責務で extension 分割する |
| ux-design.md（正本）と実装の乖離 | 仕様の二重管理 | Task 5・6 で ux-design.md を同一コミットで同期する。表示文言・a11y ラベルを変えるタスクは正本の同期を必ず確認する |

## 想定実装順（依存関係）

1. Task 1（モック基盤）→ Task 2〜6（ダッシュボード。ss-j36 の解消。Task 5・6 は ux-design.md の同期を含む）
2. Task 7〜10（学習フロー。Task 7 で `ShadowingFeatureTests` を追加し Task 8 が再利用。Task 8 / Task 10 は ViewModel 変更）
3. Task 11（オンボーディング）
4. Task 12〜21（ホーム / カタログ / 設定 / セッション / ドライブ / プライバシー。Task 14 は DownloadManager への公開 API 追加を含む。相互依存なし。並行可）

各タスクは 1 コミット。PR は 1 本（`develop` 向け）にまとめ、タイトルは Conventional Commits（例: `fix(ui): 全画面 UIUX 磨き込み（ss-j36 解消 + a11y/フィードバック是正）`）。
