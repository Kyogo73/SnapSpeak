# StoreKit 2 / Paywall / 無料制限 — 実装記録

本書は [architecture.md §10.1](./architecture.md) と [product-overview.md §10](./product-overview.md) をクライアント実装に写した記録である。フェーズ位置づけは [roadmap.md](./roadmap.md) Phase 2。

> **状態: クライアント実装済み。** サンドボックス / App Store Connect 商品の DoD は未確認（本計画 §5）。

## 0. 方針

- 単一 `StoreActor`（`AppFeature/Store/StoreActor.swift`、400 行以内）。TCA は使わない。
- 無料制限の正本は `ContentKit.EntitlementResolver`。StoreKit を import しない。プレイヤーは unlocked / locked だけを見る。
- 商品が 0 件または読込失敗なら `storeAvailable = false` とし、**すべて unlock**（IAP 未設定の TestFlight を止めない）。
- Paywall は制限到達時とロック済みカタログ項目のタップでのみ出す。初回起動・オンボーディングでは出さない。
- ドライブモードはロックしない。
- Analytics に生レシート・音声・認識テキストは載せない。

## 1. 無料 / Pro ポリシー

`EntitlementResolver.access(courseId:isFirstUnit:skillIsComposition:)`:

| 条件 | 結果 |
|------|------|
| `storeAvailable == false` | 常に unlocked |
| `isPro` | 常に unlocked |
| 非 Pro かつ瞬間英作文で当日使用数が `dailyCompositionLimit`（既定 5）以上 | locked |
| シード `course_daily_ja_en` | unlocked（作文上限を除く） |
| 他コースの先頭ユニット | unlocked（作文上限を除く） |
| それ以外 | locked |

学習日境界は 04:00（`StudyDay`）。件数は `PersistenceActor.compositionAttemptCount`。

## 2. StoreActor

起動時:

1. `EntitlementCache` を読んで暫定表示する。
2. `Product.products(for:)` を読む。空または失敗なら store unavailable。
3. `Transaction.currentEntitlements` を走査し、**verified のみ**採用する。
4. `Transaction.updates` を購読し、検証後に entitlement を更新して **必ず `finish()`** する。

状態（判定の正本は `ContentKit.SubscriptionEntitlement`）:

- Grace Period（`.inGracePeriod`）は Pro を維持する。
- Billing Retry で期限切れなら Pro を落とす。期限前なら Pro を維持する。
- `revocationDate` / `.revoked` / `.expired` は Pro を落とす。
- subscription status が取れないときは、verified な現行 entitlement を Pro のままにし、期限切れなら Grace とみなす。Billing Retry 期限切れは status があるときだけ落とす。

Restore は Paywall の明示ボタンからのみ `AppStore.sync()` する。

商品 ID（プレースホルダ）: `app.snapspeak.pro.monthly` / `app.snapspeak.pro.yearly`。

## 3. ゲート

| 入口 | 動作 |
|------|------|
| `CatalogView` | locked ならシートで Paywall。ナビしない |
| Home 続き / 今日の開始 / オンボーディング後の最初のレッスン | `RootView` で同じ判定 |
| `StandaloneLessonHost` | locked ならレッスンの代わりに Paywall |
| Review の各 Item | locked なら Paywall（閉じると skip） |
| ドライブ開始 / 走行中 | ロックしない |

## 4. Paywall UI

必須要素: 価格、期間、提供内容、購入の復元、利用規約（`https://snapspeak.app/terms`）、プライバシー（`https://snapspeak.app/privacy`）。

`paywall.*` は String Catalog（ja）。44pt、Dynamic Type、VoiceOver、色だけに依存しないロック表示、Reduce Motion では成功演出を出さない。

ローカル検証用: `App/SnapSpeak.storekit`（scheme `SnapSpeak`）。

## 5. 残るユーザー作業

- App Store Connect にサブスク商品を作る（上記 product ID）。
- サンドボックスで購入・復元・期限切れ・Grace / Billing Retry を確認する（roadmap DoD）。
- 利用規約・プライバシーページを公開する。
- 価格・トライアル日数はストア申請時に別紙で決める。
