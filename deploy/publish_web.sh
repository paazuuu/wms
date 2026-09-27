#!/usr/bin/env bash
# ビルド済みの Web 版を VPS の site/ に送る。
#   VPS_HOST=deploy@wms.example.co.jp VPS_DIR=/opt/wms ./deploy/publish_web.sh
# 送信後すぐに新しい画面が配信される（Caddy の再起動は不要）。
set -euo pipefail
: "${VPS_HOST:?VPS_HOST を指定してください（例: deploy@wms.example.co.jp）}"
VPS_DIR="${VPS_DIR:-/opt/wms}"
src="$(dirname "$0")/../mobile/build/web/"
[[ -f "${src}index.html" ]] || { echo "先に ./deploy/build_web.sh を実行してください" >&2; exit 1; }

rsync -az --delete "$src" "${VPS_HOST}:${VPS_DIR}/site/"
echo "published to ${VPS_HOST}:${VPS_DIR}/site/"
