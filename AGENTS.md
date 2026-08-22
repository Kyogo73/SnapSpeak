# AGENTS.md

SnapSpeak（iPhone 向けシャドーイング＋瞬間英作文アプリ）の開発ガイド。設計正本は `docs/`（`architecture.md` / `roadmap.md` / `product-overview.md`、オンボーディング・継続体験の UX 正本は `ux-design.md`）。実装計画・記録は `docs/phase1-implementation-plan.md`（Phase 1 初期実装）と `docs/phase2-retention-implementation-plan.md`（前倒しした継続機能。実装完了後の記録）、品質改善の実行計画は `docs/quality-pass-plan.md`。

## Cursor Cloud specific instructions

### リポジトリ構成（2 SwiftPM パッケージ + App）

- `Packages/SnapSpeakCore` … **Foundation のみに依存する中核ドメイン**（`LanguageKit` / `ScoringKit` / `CompositionKit` / `SRSKit` / `ContentCore` / `AnalyticsCore` / `HabitKit` と実行可能 `contentlint`）。外部依存は swift-crypto のみ。**この Linux VM で `swift build` / `swift test` が完結する唯一の部分**。
- `Packages/SnapSpeakiOS` … Apple 専用（SwiftUI / SwiftData / AVFoundation / Speech / UIKit）。**Linux ではコンパイル不可**。検証は macOS CI（GitHub Actions の `ios-macos` ジョブ）のみ。機能モジュールは `AppFeature` / `OnboardingFeature` / `ReviewFeature` / `ShadowingFeature` / `CompositionFeature`、インフラは `NotificationsKit` / `Persistence` / `AudioEngine` / `SpeechKit` / `ContentKit` / `DesignSystem` / `Analytics`。
- `App/` … Xcode App ターゲット。`.xcodeproj` は **XcodeGen（`App/project.yml`）から生成**（手書き・コミットしない。`.gitignore` 済み）。

### 開発環境（この VM の非自明な前提）

- Swift ツールチェーンは **swiftly** で導入済み（`~/.local/share/swiftly`、`~/.profile` に env 登録済み）。新規シェルでは通常 `swift` がそのまま使えるが、使えない場合は `. "$HOME/.local/share/swiftly/env.sh"`。
- リポジトリ直下の `.swift-version` は **`6.1`**。swiftly はこれを読んで **Swift 6.1.2** を自動選択する（CI の `swift:6.1-noble` と一致）。別バージョンを明示したい場合は `swiftly run swift +<ver> ...` かツールチェーン直パス。
- **Xcode / Apple SDK はこの Linux VM に存在しない。** iOS パッケージ・App のコンパイル/テストはローカルで再現できない。iOS 側を変更したら **必ず `ios-macos` CI を回して確認する**（このリポジトリでは実際に CI をコンパイラとして使って反復する運用）。
- フェーズ分割の正本は `docs/roadmap.md`。Phase 3 で Supabase（Auth / 同期 / Edge Functions）が入る想定。将来 Deno/TypeScript の Edge Functions など Linux 上で動くコンポーネントが追加された時点で、その部分のみこの VM 上でセットアップ・実行可能になる。

### ブランチ運用（正本は `docs/development-workflow.md`）

- `main` = **本番**（App Store 配布相当）、`develop` = **テスト環境**（TestFlight / 内部配布相当・常時検証）。どちらも直 push 禁止・PR 必須・CI 必須。
- **feature（および Cloud Agent の `cursor/*`）ブランチは実質 feature 扱い。最終的に `develop` へ集約**する（PR ベースを develop 相当に向ける）。
- **リリースは自動化済み**: `develop` が先行すると `release-pr.yml` が develop → main のリリース PR を自動作成。人間がマージすると `release.yml` が Conventional Commits から semver を計算（`scripts/next-version.sh`）して**自動でタグとドラフト GitHub Release を作成**する。hotfix は `main` から分岐し `main` と `develop` の両方へ反映する。
- CI（`.github/workflows/ci.yml`）は **全 PR** と `develop` / `main` への push で `lint` / `core-linux` / `ios-macos` を実行。`pr-title.yml` が PR タイトルの Conventional Commits 形式を強制（**PR タイトルが Squash 後のコミット subject ＝ バージョン計算の入力**になるため）。署名・TestFlight 自動化は未着手（手動）。

### ビルド / テスト / Lint（コマンド）

- 中核テスト（Linux 可）: `cd Packages/SnapSpeakCore && swift test`
- コンテンツ検証（Linux 可）: `cd Packages/SnapSpeakCore && swift run contentlint ../../Resources/Seed/course_daily_ja_en/index.json --audio-root ../../Resources/Seed/course_daily_ja_en`
- SwiftLint（Linux で手元実行する場合）: 公式 Linux バイナリは SourceKit を要するため `LD_LIBRARY_PATH=$HOME/.local/share/swiftly/toolchains/6.1.2/usr/lib swiftlint lint --strict` のようにツールチェーンの lib を通す。設定は `.swiftlint.yml`（`AppleLanguages` 書換え禁止・UI 日本語ハードコード禁止のカスタムルールを含む）。
- iOS/App（macOS のみ。CI 参照）: `.github/workflows/ci.yml` の `ios-macos` が `xcodegen generate --spec App/project.yml` → `xcodebuild build`（scheme `SnapSpeak`）→ `xcodebuild test`（scheme `SnapSpeakiOSTests`, iOS Simulator, `CODE_SIGNING_ALLOWED=NO`）。

### 非自明な注意点（ハマりどころ）

- iOS のユニットテスト（`PersistenceTests` / `ContentKitTests` / `ReviewFeatureTests` / `NotificationsKitTests`）は **ホストアプリを使わないロジックテスト**にしてある。SwiftPM の静的ライブラリ製品を bundle_loader 経由で解決するとリンクに失敗するため、テストターゲットは必要な製品を直接リンクする（`App/project.yml` 参照）。
- `Packages/SnapSpeakCore/Package.swift` は `platforms` を明示している（swift-crypto の `SHA256` が macOS 10.15+ を要求するため。未指定だと macOS ビルドが落ちる）。
- Bluetooth 系オーディオオプションは Xcode 16.4 SDK 準拠で `.allowBluetooth` を使用（`.allowBluetoothHFP` は新しい SDK 専用）。SDK 更新時に見直す。
- シードの音声ファイル（`Resources/Seed/.../audio/*.m4a`）は現状 checksum 整合のための**ダミーバイト**で、実再生できない。`AVAudioFile` を使う実機フローは本番収録音声に差し替えてから。差し替え時は checksum / durationMs / captionSegments を再生成し `contentlint` で再検証する。

### 不変条件（`docs/roadmap.md`「フェーズ横断の不変条件」より、コード変更時に厳守）

- TCA を導入しない（MVVM + Swift Concurrency）。core は Apple フレームワークを import しない。
- シャドーイング採点はオンデバイス ASR に閉じる（サーバー認識へフォールバックしない）。指標は「スクリプト一致率／語の再現度」であり発音精度ではない。
- 学習履歴・`ReviewEvent` は追記型。SRS カードを LWW しない。
- UI 文字列は String Catalog 経由（日本語ハードコード禁止）。`AppleLanguages` を書き換えない。
- コンテンツは言語ペア（BCP-47）必須。未知の高い `schemaVersion` は拒否しローカルを維持する。
