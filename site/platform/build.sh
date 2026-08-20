#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

RENDER_EXTRA=""
if [ -z "${APP_KEY_SHA256:-}" ]; then
    RENDER_EXTRA="--allow-missing"
fi
python3 "$SCRIPT_DIR/render_assetlinks.py" \
    "$SCRIPT_DIR/public/.well-known/assetlinks.json" $RENDER_EXTRA

cd "$SCRIPT_DIR/../.."
pnpm install --frozen-lockfile
pnpm --filter efa-proto-ts generate
pnpm --filter efa-platform build
