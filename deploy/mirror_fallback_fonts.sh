#!/usr/bin/env bash
# Flutter Web は、アプリに同梱していない文字（日本語・中国語・韓国語・絵文字など）の
# フォントを実行時に fonts.gstatic.com（Google）から読み込む。中国からは Google に
# つながらず、社内ネットワークで外部を塞いでいる場合も同じで、その環境では画面の
# 文字が「□」になる。
#
# そこでビルド時に、エンジンが参照するフォールバックフォントをすべて取得して
# build/web/fonts/fallback/ に置き、起動設定（fontFallbackBaseUrl）をそこへ向ける。
# ブラウザは必要な文字の分だけを VPS から取りに行く。
#
# 取得したファイルは deploy/.cache/fonts に保存し、次回のビルドから再利用する。
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
web="${1:-$here/../mobile/build/web}"
cache="$here/.cache/fonts"
dest="$web/fonts/fallback"
upstream="https://fonts.gstatic.com/s/"

[[ -f "$web/main.dart.js" && -f "$web/flutter_bootstrap.js" ]] \
  || { echo "ビルド済みの Web 版が見つかりません: $web" >&2; exit 1; }

list="$(mktemp)"
trap 'rm -f "$list"' EXIT
grep -oE '"[a-z0-9]+/v[0-9]+/[A-Za-z0-9_-]+(\.[0-9]+)?\.(woff2|ttf|otf)"' "$web/main.dart.js" \
  | tr -d '"' | sort -u > "$list"
total=$(wc -l < "$list")
[[ "$total" -gt 0 ]] || { echo "フォント一覧を取り出せませんでした（Flutter の版が変わった可能性）" >&2; exit 1; }

mkdir -p "$cache"
missing=0
while read -r f; do [[ -s "$cache/$f" ]] || missing=$((missing + 1)); done < "$list"
echo "fallback fonts: $total files ($missing to download)"
if [[ "$missing" -gt 0 ]]; then
  # 取得できなかったファイルが 1 つでもあれば失敗扱い（中途半端な配信を防ぐ）。
  while read -r f; do [[ -s "$cache/$f" ]] || echo "$f"; done < "$list" \
    | xargs -P 16 -I{} sh -c 'mkdir -p "$(dirname "$1/$2")" && curl -fsS --retry 3 -o "$1/$2.part" "$3$2" && mv "$1/$2.part" "$1/$2"' _ "$cache" {} "$upstream"
fi

rm -rf "$dest"
mkdir -p "$dest"
while read -r f; do
  mkdir -p "$dest/$(dirname "$f")"
  cp "$cache/$f" "$dest/$f"
done < "$list"

# 起動設定: フォールバックフォントの取得先を自サーバーに向ける。
if ! grep -q 'fontFallbackBaseUrl' "$web/flutter_bootstrap.js"; then
  sed -i 's#_flutter.loader.load({#_flutter.loader.load({\n  config: { fontFallbackBaseUrl: "fonts/fallback/" },#' "$web/flutter_bootstrap.js"
fi
grep -q 'fontFallbackBaseUrl: "fonts/fallback/"' "$web/flutter_bootstrap.js" \
  || { echo "flutter_bootstrap.js を書き換えられませんでした" >&2; exit 1; }

echo "fallback fonts: $(du -sh "$dest" | cut -f1) in $dest"
