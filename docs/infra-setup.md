# インフラセットアップ（Cloudflare R2 / 署名 / TestFlight）

本書は **ユーザーが手元で辿る運用手順** である。設計の正本は [architecture.md](./architecture.md) §8.1（CDN 構成）と [development-workflow.md](./development-workflow.md) §5・§7（リリースと配布チャネル）。払い出し・秘密情報の登録はリポジトリ外の作業（バックログ `ss-xux`）であり、本リポジトリの CI は秘密情報を扱わない。

---

## 1. Cloudflare R2（コンテンツ CDN）

Phase 1 から CDN 配信は必須。採用は **Cloudflare R2**（S3 互換 + Cloudflare CDN、egress 無料）。個人学習データ・認証情報は置かない（それらは Phase 3 の Supabase 側）。

公式手順の起点:

- バケット作成: [R2 get started](https://developers.cloudflare.com/r2/get-started/)
- API トークン: [R2 Authentication](https://developers.cloudflare.com/r2/api/tokens/)
- 公開読み取り: [Public buckets](https://developers.cloudflare.com/r2/buckets/public-buckets/)
- S3 互換 API: `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`（region は `auto`）

### 1.1 アカウント

1. [Cloudflare ダッシュボード](https://dash.cloudflare.com/) にログインする。アカウントが無ければ作成する。
2. 左上のアカウントセレクタで、R2 を置くアカウントを選ぶ。
3. **R2 を購入（有効化）する。** API トークン発行の前提。無料枠（ストレージ 10GB・Class A 100 万 / Class B 1,000 万 / egress 無料）で Phase 1〜2 の教材量は収まる想定（[architecture.md](./architecture.md) §8.1）。
4. アカウント ID を控える: ダッシュボード右サイドバー、または [Find account and zone IDs](https://developers.cloudflare.com/fundamentals/account/find-account-and-zone-ids/)。32 桁の hex。S3 エンドポイントに使う。

### 1.2 バケット

1. ダッシュボードで **R2 object storage** を開く（[Overview](https://dash.cloudflare.com/?to=/:account/r2/overview)）。
2. **Create bucket** を押す。
3. 名前は **アカウント内で一意** の kebab-case（グローバル一意ではない）。推奨: `snapspeak-cdn`（本番）/ `snapspeak-cdn-dev`（検証用を分ける場合）。
4. **Location**: 作成時に **Asia-Pacific（`APAC`）を指定する**。主要ユーザーが日本のため。Location Hint は **作成時だけ** 効く。作成後は変更できない。同名で削除して作り直しても、最初の配置が維持される（[R2 data location](https://developers.cloudflare.com/r2/reference/data-location/)）。`None`（Automatic）で作ると、作成者の最寄りリージョンに固定される。
5. **Create bucket** で作成する。
6. バケットの **Settings** で **S3 API** エンドポイントを控える。形は  
   `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`  
   （バケット名はパスではなく SDK の `Bucket` 引数に渡す）。

オブジェクトは **公開読み取り** にする（クライアントは匿名 HTTPS GET のみ。書き込みはトークン所持者だけ）。

1. 同じ Settings で **Custom Domains** → **Add**。本番は architecture の例どおり `cdn.snapspeak.app`。
   - このホスト名のゾーンが **同じ Cloudflare アカウント** にあること（未追加ならゾーン追加、または [partial CNAME setup](https://developers.cloudflare.com/dns/zone-setups/partial-setup/)）。
   - 表示される DNS レコードを確認して **Connect Domain**。数分で Initializing → Active。
2. ドメインがまだ無い検証段階では **Public Development URL**（`*.r2.dev`）を Enable してよい。`r2.dev` はレート制限あり・本番禁止。CNAME を `r2.dev` に向けない。
3. 本番では `r2.dev` を Disable し、カスタムドメインだけを残す。

キャッシュ（architecture §8.1 と一致させる）:

| パス | Cache-Control | 理由 |
|------|---------------|------|
| `manifest/index.json` | `public, max-age=300` | 更新を数分で伝播する |
| `courses/<courseId>/<releaseId>/*` | `public, max-age=31536000, immutable` | release 配下は上書きしない |

カスタムドメイン経由では既定キャッシュ対象外の拡張子もある。JSON / m4a を確実にキャッシュするなら Cache Everything 相当の Cache Rule をゾーンに足す。

### 1.3 API トークン（最小権限）

アップロード用トークンは **オブジェクトの読み書きだけ** に絞る。アカウント横断の Admin は使わない。

1. [R2 Overview](https://dash.cloudflare.com/?to=/:account/r2/overview) の Account Details で **API Tokens** の **Manage** を開く。
2. **Create User API token**（個人に紐づく）または Super Admin なら **Create Account API token**。
3. 権限:
   - Permission: **Object Read & Write**（S3 互換 API 専用。Cloudflare REST API では使えない）
   - Specify bucket(s): **今作ったバケットだけ**（`snapspeak-cdn`）
4. 作成直後に表示される **Access Key ID** と **Secret Access Key** を控える。Secret は再表示できない。
5. トークン値そのもの（Bearer）は S3 互換クライアントには使わない。ダッシュボードが出す Access Key / Secret を使う。

使ってよい操作: `PutObject` / `GetObject` / `HeadObject` / `DeleteObject` / `ListObjectsV2`（当該バケット）。  
使ってはいけない操作: バケット作成・削除、他バケット、アカウント設定、Workers デプロイ。

動作確認（ローカル。値はシェル履歴に残さない）:

```bash
# 例: aws cli。region は auto。ACL ヘッダは送らない（R2 非対応）。
aws s3 cp ./probe.txt "s3://snapspeak-cdn/probe.txt" \
  --endpoint-url "https://<ACCOUNT_ID>.r2.cloudflarestorage.com" \
  --cache-control "public, max-age=300"
curl -I "https://cdn.snapspeak.app/probe.txt"   # または r2.dev の確認 URL
aws s3 rm "s3://snapspeak-cdn/probe.txt" \
  --endpoint-url "https://<ACCOUNT_ID>.r2.cloudflarestorage.com"
```

`rclone` でも可。プロファイル例:

```ini
[snapspeak-r2]
type = s3
provider = Cloudflare
access_key_id = <ACCESS_KEY_ID>
secret_access_key = <SECRET_ACCESS_KEY>
endpoint = https://<ACCOUNT_ID>.r2.cloudflarestorage.com
acl =
```

### 1.4 architecture §8.1 の URL 設計との対応

公開 URL の正はカスタムドメイン（例 `https://cdn.snapspeak.app`）。S3 エンドポイントは **アップロード専用** でクライアントに出さない。

| 論理パス（architecture §8.1 / §7.3） | バケットオブジェクトキー | 公開 URL 例 |
|--------------------------------------|--------------------------|-------------|
| マニフェスト | `manifest/index.json` | `https://cdn.snapspeak.app/manifest/index.json` |
| コース release の index | `courses/<courseId>/<releaseId>/index.json` | `https://cdn.snapspeak.app/courses/course_daily_ja_en/course_daily_ja_en__r2/index.json` |
| お手本音声 | `courses/<courseId>/<releaseId>/audio/<file>.m4a` | 同プレフィックス + `audio/item_p_001.m4a` |

マニフェスト JSON の `contentUrl` は **公開 URL**（カスタムドメイン）を書く。S3 API ホストや `r2.dev` を本番マニフェストに書かない。

`releaseId` 配下は immutable。同じキーを上書きして「更新」しない。更新は新しい `releaseId` / `revision` を追加し、マニフェストだけ差し替える（[architecture.md](./architecture.md) §7.3）。

個人データ・録音・API キー・`.p8` をこのバケットに置かない。

### 1.5 Cloud Agents Secrets への登録名（提案）

Cursor Cloud Agents はリポジトリの `.cursor/mcp.json` を読まない。秘密は **Cursor ダッシュボード（個人またはチーム）の Cloud Agents Secrets** にユーザーが登録する（`ss-xux`）。CI（GitHub Actions）にはまだ置かない。GitHub Actions での署名・配布自動化は §2 の将来作業。

推奨する登録名（値はダッシュボードにだけ置く）:

| Secret 名 | 入れる値 | 備考 |
|-----------|----------|------|
| `R2_ACCOUNT_ID` | Cloudflare アカウント ID（32 桁 hex） | エンドポイント組み立て用。漏洩してもトークン無しでは書けないが、公開しない |
| `R2_BUCKET` | `snapspeak-cdn` | バケット名 |
| `R2_S3_ENDPOINT` | `https://<ACCOUNT_ID>.r2.cloudflarestorage.com` | リージョン付きエンドポイントを使う場合だけ差し替え |
| `R2_ACCESS_KEY_ID` | トークンの Access Key ID | **必須の秘密** |
| `R2_SECRET_ACCESS_KEY` | トークンの Secret Access Key | **必須の秘密** |
| `R2_PUBLIC_BASE_URL` | `https://cdn.snapspeak.app` | 秘密ではない。マニフェストの `contentUrl` プレフィックス。エージェントが間違ったホストを書かないための固定値 |

登録後の確認（エージェントや手元スクリプトが参照するとき）:

- `R2_S3_ENDPOINT` + `R2_ACCESS_KEY_ID` + `R2_SECRET_ACCESS_KEY` で `ListObjectsV2` が当該バケットにだけ通る。
- `R2_PUBLIC_BASE_URL` で `manifest/index.json` が匿名 GET できる（置いたあと）。
- トークンをローテーションしたら Secrets を更新し、古いトークンはダッシュボードで revoke する。

---

## 2. 署名 / TestFlight（現状と将来の前提）

### 2.1 現状（未自動化）

| 項目 | 状態 |
|------|------|
| CI の iOS ビルド | `ios-macos` がシミュレータ向け `xcodebuild build` / `test`。`CODE_SIGNING_ALLOWED=NO`（[.github/workflows/ci.yml](../.github/workflows/ci.yml)、[App/project.yml](../App/project.yml)） |
| 署名付き Archive | **手動**。Xcode またはローカル `xcodebuild archive` |
| TestFlight アップロード | **手動**。`develop` = テスト環境（内部 / TestFlight 相当） |
| App Store 提出 | **手動**。`main` = 本番。タグは [release.yml](../.github/workflows/release.yml) が semver を計算してドラフト GitHub Release を作るだけ |
| GitHub Release | 自動化済み（ドラフト）。公開は人間 |
| 秘密情報 | CI は扱わない。[release.yml](../.github/workflows/release.yml) 末尾の TODO コメントが将来自動化の置き場 |

実配布するときに [App/project.yml](../App/project.yml) の `MARKETING_VERSION` と `CURRENT_PROJECT_VERSION` をタグと整合させる（[development-workflow.md](./development-workflow.md) §5）。git タグの自動採番とは独立。

### 2.2 将来自動化に必要な前提（未着手。揃えるもの）

導入時は GitHub Environments（例 `testflight` / `appstore`）と OIDC または Environment secrets で管理する。リポジトリの Actions secrets に平置きしない。

**Apple Developer / 証明書**

| 前提 | 用途 | 置き場の目安 |
|------|------|----------------|
| Apple Developer Program 加入（Team ID） | 署名と App Store Connect | チーム設定。Secret 名案 `APPLE_TEAM_ID` |
| App ID / bundle id `app.snapspeak.SnapSpeak` | 既存。Capabilities（マイク・Speech・Background Audio）と一致 | App Store Connect / Developer portal |
| Apple Distribution 証明書（.p12 またはクラウド署名） | Archive のコード署名 | Environment secret、または App Store Connect のクラウド署名 |
| 証明書パスフレーズ | .p12 を使う場合 | `APPLE_DISTRIBUTION_CERT_PASSWORD` |
| App Store 用 Provisioning Profile | `xcodebuild -exportArchive` | プロファイルファイル、または Xcode Cloud / 自動署名 |
| 開発用デバイス登録 | 内部 Ad Hoc を使う場合のみ。TestFlight なら不要 | Developer portal |

**App Store Connect API**

| 前提 | 用途 | 置き場の目安 |
|------|------|----------------|
| App Store Connect API キー（.p8） | `altool` / `notarytool` 相当・Transporter・Fastlane `pilot` / `deliver` | Environment secret `APP_STORE_CONNECT_API_KEY_P8`（PEM 本文） |
| Key ID | JWT の `kid` | `APP_STORE_CONNECT_API_KEY_ID` |
| Issuer ID | JWT の `iss` | `APP_STORE_CONNECT_ISSUER_ID` |
| キーの役割 | App Manager 以上（アップロードと TestFlight）。Admin は過剰 | 最小権限のキーを発行し、漏洩時は即座に revoke |

**アプリ側メタデータ（自動化の入力）**

| 前提 | 用途 |
|------|------|
| App Store Connect 上のアプリレコード | 初回は手動作成。以降のビルド紐付け |
| TestFlight 内部グループ | `develop` 相当ビルドの配布先 |
| `ITSAppUsesNonExemptEncryption` 等の Export Compliance | 初回質問。以降のアップロードでブロックしない |
| Privacy Nutrition Labels / Privacy Manifest | Archive の Privacy Report と一致させる（roadmap Phase 1 DoD） |

**GitHub / CI（導入時に設計する。今は作らない）**

| 前提 | 用途 |
|------|------|
| Environment `testflight`（`develop` のみ） / `appstore`（`main` + タグのみ） | 秘密のスコープと必須レビュアー |
| macOS ランナー + 署名を許可した `xcodebuild archive` | `CODE_SIGNING_ALLOWED=NO` のままでは Archive できない |
| `xcodegen generate` → archive → `-exportArchive` → upload | [release.yml](../.github/workflows/release.yml) の TODO に書いた流れ |
| 失敗時の手動フォールバック | 証明書期限切れ・API キー失効でも Xcode Organizer から上げられること |

iOS の TestFlight 提出に **Apple notary（macOS 用 notarize）は不要**。[release.yml](../.github/workflows/release.yml) の TODO も upload のみとしている。

自動化に着手するまで、本節の表はチェックリストとしてだけ使う。値をリポジトリにコミットしない。
