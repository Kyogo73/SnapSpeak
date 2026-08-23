# SnapSpeak

iPhone 向け語学学習アプリ。中核は **シャドーイング** と **瞬間英作文** の2機能です。主要ユースケースの第一級として **運転中の語学学習（ドライブモード: 車内・ハンズフリー・アイズフリーの音声のみ自動進行）** に特化した UI/UX を採ります。

まず日本人向け英語学習（UI は日本語）から開始し、学習言語（L2）の拡張、さらに海外展開（UI 多言語化・母語 L1 の追加）まで見据えた設計です。多言語化・国際化は後付けではなく、最初から第一級の要件として組み込みます。

フェーズ分割の正本は [docs/roadmap.md](docs/roadmap.md) です。オンボーディングと継続体験の UX 正本は [docs/ux-design.md](docs/ux-design.md)（ドライブモードは同 §10）、実装分解は [docs/phase2-retention-implementation-plan.md](docs/phase2-retention-implementation-plan.md) と [docs/drive-mode-implementation-plan.md](docs/drive-mode-implementation-plan.md) です。

中核ドメインは `Packages/SnapSpeakCore`（`HabitKit` を含む。Linux で `swift test` 可能）。iOS 機能は `Packages/SnapSpeakiOS`（`OnboardingFeature` / `ReviewFeature` / `NotificationsKit` ほか。macOS CI で検証）。

## ドキュメント

| 文書 | 内容 |
|------|------|
| [プロダクト概要](docs/product-overview.md) | ターゲット、課題と価値、コア学習ループ、差別化、KPI |
| [アーキテクチャ](docs/architecture.md) | システム構成、モジュール、音声パイプライン、採点、SRS、データモデル、国際化、非機能要件 |
| [ロードマップ](docs/roadmap.md) | Phase 1〜4 の目的・機能・技術タスク・完了基準・リスクと依存関係 |
| [UX 設計](docs/ux-design.md) | オンボーディング・継続体験・ドライブモードの正本。ストリーク / デイリーゴール / 今日の学習のルール仕様、画面仕様、状態マトリクス、通知戦略、a11y、i18n、計測、ドライブモード（§10: 安全原則・音声シーケンス・割り込み設計） |
| [開発ワークフロー](docs/development-workflow.md) | ブランチ運用（main=本番 / develop=テスト）、PR・コミット規約、リリース・hotfix 手順、CI/CD ゲート |
| [インフラセットアップ](docs/infra-setup.md) | Cloudflare R2 の払い出し、Cloud Agents Secrets 名、署名 / TestFlight の現状と将来前提 |
| [実機 QA チェックリスト](docs/device-qa-checklist.md) | Phase 1 / Phase 2 DoD のうち実機でしか確認できない項目（音声経路・権限・機内モード・ドライブ等） |
| [Phase 1 実装計画](docs/phase1-implementation-plan.md) | 初期実装の分解（モジュール骨格、シード、CI、コミット順）。実装済み |
| [Phase 2 前倒し実装計画](docs/phase2-retention-implementation-plan.md) | オンボーディング + 継続機能（復習キュー / ストリーク / ゴール / 通知）の実装分解。実装完了後の記録 |
| [品質改善計画](docs/quality-pass-plan.md) | リファクタリング・UI/UX 是正・堅牢性・自動テスト追加の実行計画と QA チェックリスト |
| [ドライブモード実装計画](docs/drive-mode-implementation-plan.md) | ドライブモード MVP の実装分解（DriveKit スクリプト生成 / DriveModeFeature / AudioEngine 拡張 / TTS フォールバック / テスト戦略 / コミット順） |

## 技術スタック（確定）

- **クライアント**: SwiftUI / iOS 17+ / MVVM + Swift Concurrency
- **永続化**: SwiftData（オフラインファースト。v1 から VersionedSchema）
- **音声**: AVFoundation + Speech framework（**オンデバイス必須**。シャドーイングはサーバー認識へ暗黙フォールバックしない）
- **モジュール**: Swift Package によるマルチモジュール
- **配信 (MVP / Phase 1)**: 静的 JSON + 音声ファイルを **CDN から配信**（マニフェストで差分更新）。アプリ内シードは CDN 障害時・初回オフライン保証
- **バックエンド**: Phase 1 はコンテンツ静的配信のみ（アカウントなし）。**Phase 3** で Supabase（Auth / 進捗同期 / Edge Functions）を導入。Phase 2 はクライアント側の定着機能と StoreKit 2。Phase 4 でリージョン・プライバシー対応
