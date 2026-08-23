# コード忠実 HTML モックアップ

## 目的

iOS シミュレータを持たない環境で視覚レビューを回すため、SwiftUI コードを 1:1 で写した静的 HTML を置く（ss-j36 を生んだ前回レビューと同手法）。

## 写し方

| SwiftUI | HTML / CSS |
|---------|------------|
| ビュー階層（`VStack` / `HStack` / `ZStack`） | flexbox（`flex-direction: column` / `row` / 重ねは `position`） |
| `Typography.title` | 28px system-ui（regular） |
| `Typography.headline` | 17px system-ui（semibold） |
| `Typography.body` | 17px system-ui（regular） |
| `Typography.callout` | 16px system-ui（regular） |
| `Typography.caption` | 12px system-ui（regular） |
| `Typography.score` | 22px system-ui（`font-variant-numeric: tabular-nums`） |
| `Colors.accent` | iOS システムアクセント（light `#007AFF` / dark `#0A84FF`） |
| `Colors.secondaryFill` | iOS `secondaryLabel`（light `rgba(60,60,67,0.60)` / dark `rgba(235,235,245,0.60)`） |
| `Colors.warning` | iOS orange（light `#FF9500` / dark `#FF9F0A`） |
| `Colors.background` | iOS `systemBackground` |
| `CardContainer` | 角丸 16px + `secondarySystemBackground` + padding 16px |
| 文言 | `Resources/Localizable.xcstrings` の ja 値を転記 |

light / dark は `prefers-color-scheme` で切り替える。

## レビュー手順

1. ブラウザで該当 HTML を開く。
2. light / dark（OS または DevTools の `prefers-color-scheme`）と幅 375px（iPhone 最小相当）で確認する。
3. 指摘は beads または PR コメントに画面名つきで記録する。

## ダッシュボード（Phase 1）

| ファイル | 内容 |
|----------|------|
| [dashboard-before.html](./dashboard-before.html) | Phase 1 前（ss-j36 A〜D が再現する現状） |
| [dashboard.html](./dashboard.html) | Phase 1 後（0 件日プレースホルダ / 指標名 / at-risk テキスト / 30 日窓 / 達成日 ✓ / チャート要約） |

## 免責

モックはレビュー用アーティファクトである。実装の正本は SwiftUI コードと `docs/ux-design.md`。乖離を見つけたらモックを直す（モックが正本にならない）。
