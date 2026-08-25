# コード忠実 HTML モックアップ

## 目的

iOS シミュレータを持たない環境で視覚レビューを回すため、SwiftUI コードを 1:1 で写した静的 HTML を置く（ss-j36 を生んだ前回レビューと同手法）。

## 写し方

| SwiftUI | HTML / CSS |
|---------|------------|
| ビュー階層（`VStack` / `HStack` / `ZStack`） | flexbox（`flex-direction: column` / `row` / 重ねは `position`） |
| `Typography.title` | 28px `ui-rounded`（regular） |
| `Typography.headline` | 17px `ui-rounded`（semibold） |
| `Typography.body` | 17px system-ui（regular） |
| `Typography.callout` | 16px system-ui（regular） |
| `Typography.caption` | 12px system-ui（regular） |
| `Typography.score` | 22px `ui-rounded`（`font-variant-numeric: tabular-nums`） |
| `Colors.accent` | 教育ティール（light `#0F766E` / dark `#5EEAD4`） |
| `Colors.onAccent` | light `#FFFFFF` / dark `#042F2E` |
| `Colors.secondaryFill` | iOS `secondaryLabel`（light `rgba(60,60,67,0.60)` / dark `rgba(235,235,245,0.60)`） |
| `Colors.warning` | iOS orange（light `#FF9500` / dark `#FF9F0A`） |
| `Colors.background` | 暖色キャンバス（light `#F3F6F4` / dark `#0C1211`） |
| `CardContainer` | 角丸 22px continuous + `cardFill` `#FFFEFB` / `#16201E` + 1pt stroke + 弱い影 + padding 18px |
| 文言 | `Resources/Localizable.xcstrings` の ja 値を転記 |

light / dark は `prefers-color-scheme` で切り替える。

## レビュー手順

1. ブラウザで該当 HTML を開く。
2. light / dark（OS または DevTools の `prefers-color-scheme`）と幅 375px（iPhone 最小相当）で確認する。
3. 指摘は beads または PR コメントに画面名つきで記録する。

## ホーム / 復習 / ドライブ / プライバシー（Task 12 / 17–21）

| ファイル | 内容 |
|----------|------|
| [home.html](./home.html) | ドライブカードの chevron、loading プレースホルダ、回復カード |
| [review_summary.html](./review_summary.html) | 目標達成リング（Reduce Motion 静止） |
| [drive.html](./drive.html) | 開始のシステムナビ、グランス状態語、ノート聞き直し |
| [privacy.html](./privacy.html) | 外部リンクアイコンと hint |

## ダッシュボード（Phase 1）

| ファイル | 内容 |
|----------|------|
| [dashboard-before.html](./dashboard-before.html) | Phase 1 前（ss-j36 A〜D が再現する現状） |
| [dashboard.html](./dashboard.html) | Phase 1 後（0 件日プレースホルダ / 指標名 / at-risk テキスト / 30 日窓 / 達成日 ✓ / チャート要約） |

## デザイン判断の参照

- プロダクト全体: `design-system/snapspeak/MASTER.md`（ui-ux-pro-max。子供向けフォント / インディゴパレットは却下し iOS セマンティックトークンに固定）
- この画面: `design-system/snapspeak/pages/dashboard.md`
- Open Design はこの Cloud 環境では daemon 未接続のため使わない。視覚レビューは本ディレクトリの HTML。

## 免責

モックはレビュー用アーティファクトである。実装の正本は SwiftUI コードと `docs/ux-design.md`。乖離を見つけたらモックを直す（モックが正本にならない）。
