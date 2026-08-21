# AGENTS.md

## Cursor Cloud specific instructions

このリポジトリは現時点では **ドキュメント専用（実装前の設計・計画フェーズ）** です。

- 中身は Markdown のみ: `README.md` と `docs/`（`architecture.md` / `product-overview.md` / `roadmap.md`）。
- アプリのソースコード、`Package.swift`、`.xcodeproj`、`package.json` などのビルド／依存関係マニフェストは存在しません。したがって **インストールする依存関係・実行するサービス・ビルド・自動テスト・Lint 設定はありません**。
- 対象プロダクト（SnapSpeak）は **iOS / SwiftUI アプリ** です（`README.md` の技術スタック参照）。ビルド・実行には **macOS + Xcode** が必要で、この Linux ベースの Cloud Agent VM では本来のアプリをビルド／実行できません。
- 実装が始まるまで、この環境で意味のある検証は **ドキュメント整合性チェック** のみです。README/docs 内の相対リンクが実在ファイルを指すかを確認できます（例）:

```bash
python3 - <<'PY'
import re, os, glob, sys
md=glob.glob("README.md")+glob.glob("docs/*.md")
rx=re.compile(r'\[[^\]]*\]\(([^)]+)\)'); errs=0
for f in md:
    base=os.path.dirname(f); text=open(f,encoding="utf-8").read()
    for m in rx.finditer(text):
        t=m.group(1).strip().split()[0].split('#')[0]
        if not t or t.startswith(("http://","https://","mailto:")): continue
        p=os.path.normpath(os.path.join(base,t))
        if not os.path.exists(p): print("BROKEN:",f,"->",t); errs+=1
sys.exit(1 if errs else 0)
PY
```

- フェーズ分割の正本は `docs/roadmap.md`。Phase 3 で Supabase（Auth / 同期 / Edge Functions）が入る想定です。将来 Deno/TypeScript の Edge Functions など Linux 上で動くコンポーネントが追加された時点で、その部分のみ Cloud VM 上でセットアップ・実行可能になります。

### ブランチ運用（正本は `docs/development-workflow.md`）

- `main` = **本番**（App Store 配布相当）、`develop` = **テスト環境**（TestFlight / 内部配布相当・常時検証）。どちらも直 push 禁止・PR 必須・CI 必須。
- **feature（および Cloud Agent の `cursor/*`）ブランチは実質 feature 扱い。最終的に `develop` へ集約**する（PR ベースを develop 相当に向ける）。
- **リリースは semver タグ（例 `v1.0.0`）を切って `develop` → `main` へマージ**。hotfix は `main` から分岐し `main` と `develop` の両方へ反映する。
- CI（`.github/workflows/ci.yml`）は `develop` / `main` 宛 PR と push で `lint` / `core-linux` / `ios-macos` を実行。`v*` タグ push で `release.yml` が GitHub Release（ドラフト）を作成する。署名・TestFlight 自動化は未着手（手動）。
