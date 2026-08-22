#!/usr/bin/env bash
# 直近の v タグと Conventional Commits から次の semver タグ名を計算する。
#
# 使い方: scripts/next-version.sh [<ref>]   （既定: HEAD）
# 出力:   次のタグ名（例 v0.2.0）を stdout に 1 行
# 終了コード:
#   0 = 次バージョンを出力した
#   2 = スキップ（<ref> に既に v タグが付いている / 前回タグから新規コミットなし）
#
# バンプ規則（docs/development-workflow.md §4 のコミット規約が入力）:
#   major: subject が `type!:`（例 feat!:）または body に BREAKING CHANGE
#   minor: subject が `feat:` / `feat(scope):`
#   patch: それ以外（fix / docs / chore / ci / refactor / ...）
#   タグが 1 つも無い場合の初回は v0.1.0
set -euo pipefail

ref="${1:-HEAD}"

# 対象コミットに既に vX.Y.Z タグが付いていればスキップ（再実行の冪等性）
if git describe --tags --exact-match --match 'v[0-9]*' "$ref" >/dev/null 2>&1; then
    echo "skip: $ref is already tagged ($(git describe --tags --exact-match --match 'v[0-9]*' "$ref"))" >&2
    exit 2
fi

last="$(git describe --tags --abbrev=0 --match 'v[0-9]*' "$ref" 2>/dev/null || true)"

if [ -z "$last" ]; then
    echo "v0.1.0"
    exit 0
fi

range="$last..$ref"
if [ -z "$(git rev-list "$range")" ]; then
    echo "skip: no commits since $last" >&2
    exit 2
fi

bump="patch"
# subject + body を走査（squash マージなら PR タイトル、merge commit なら配下の実コミットが対象になる）
if git log --format='%s%n%b' "$range" | grep -Eq '^[a-z]+(\([^)]*\))?!: |^BREAKING CHANGE'; then
    bump="major"
elif git log --format='%s' "$range" | grep -Eq '^feat(\([^)]*\))?: '; then
    bump="minor"
fi

version="${last#v}"
IFS='.' read -r major minor patch <<<"$version"
case "$bump" in
major) major=$((major + 1)); minor=0; patch=0 ;;
minor) minor=$((minor + 1)); patch=0 ;;
patch) patch=$((patch + 1)) ;;
esac

echo "v${major}.${minor}.${patch}"
