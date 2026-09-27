#!/usr/bin/env bash
# Flutter Web 版をビルドする。出力先: mobile/build/web
#
# CanvasKit などの実行ファイルも自前で配信する（--no-web-resources-cdn）。
# 日本語・中国語などのフォントも VPS から配信する（mirror_fallback_fonts.sh）。
# 中国や社内ネットワークから Google に出られなくても画面が正しく表示されるように。
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../mobile"

defines=()
[[ -n "${SUPABASE_URL:-}" ]] && defines+=("--dart-define=SUPABASE_URL=${SUPABASE_URL}")
[[ -n "${SUPABASE_ANON_KEY:-}" ]] && defines+=("--dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}")

flutter pub get
flutter build web --release --no-web-resources-cdn "${defines[@]}"
"$here/mirror_fallback_fonts.sh" "$(pwd)/build/web"
echo "built: $(pwd)/build/web"
