# SnapSpeak

iPhone 向け語学学習アプリ。中核は **シャドーイング** と **瞬間英作文** の2機能です。

まず日本人向け英語学習（UI は日本語）から開始し、学習言語（L2）の拡張、さらに海外展開（UI 多言語化・母語 L1 の追加）まで見据えた設計です。多言語化・国際化は後付けではなく、最初から第一級の要件として組み込みます。

フェーズ分割の正本は [docs/roadmap.md](docs/roadmap.md) です。オンボーディングと継続体験の UX 正本は [docs/ux-design.md](docs/ux-design.md)、実装分解は [docs/phase2-retention-implementation-plan.md](docs/phase2-retention-implementation-plan.md) です。

中核ドメインは `Packages/SnapSpeakCore`（`HabitKit` を含む。Linux で `swift test` 可能）。iOS 機能は `Packages/SnapSpeakiOS`（`OnboardingFeature` / `ReviewFeature` / `NotificationsKit` ほか。macOS CI で検証）。

## ドキュメント

| 文書 | 内容 |
|------|------|
| [プロダクト概要](docs/product-overview.md) | ターゲット、課題と価値、コア学習ループ、差別化、KPI |
| [アーキテクチャ](docs/architecture.md) | システム構成、モジュール、音声パイプライン、採点、SRS、データモデル、国際化、非機能要件 |
| [ロードマップ](docs/roadmap.md) | Phase 1〜4 の目的・機能・技術タスク・完了基準・リスクと依存関係 |
| [開発ワークフロー](docs/development-workflow.md) | ブランチ運用（main=本番 / develop=テスト）、PR・コミット規約、リリース・hotfix 手順、CI/CD ゲート |

## 技術スタック（確定）

- **クライアント**: SwiftUI / iOS 17+ / MVVM + Swift Concurrency
- **永続化**: SwiftData（オフラインファースト。v1 から VersionedSchema）
- **音声**: AVFoundation + Speech framework（**オンデバイス必須**。シャドーイングはサーバー認識へ暗黙フォールバックしない）
- **モジュール**: Swift Package によるマルチモジュール
- **配信 (MVP / Phase 1)**: 静的 JSON + 音声ファイルを **CDN から配信**（マニフェストで差分更新）。アプリ内シードは CDN 障害時・初回オフライン保証
- **バックエンド**: Phase 1 はコンテンツ静的配信のみ（アカウントなし）。**Phase 3** で Supabase（Auth / 進捗同期 / Edge Functions）を導入。Phase 2 はクライアント側の定着機能と StoreKit 2。Phase 4 でリージョン・プライバシー対応
