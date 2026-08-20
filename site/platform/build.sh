#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

RENDER_EXTRA=""
if [ -z "${APP_KEY_SHA256:-}" ]; then
    if [ "${ALLOW_MISSING_APP_KEY_SHA256:-}" != "1" ]; then
        echo "error: APP_KEY_SHA256 is not set; refusing to build with a placeholder assetlinks.json." >&2
        echo "Provision APP_KEY_SHA256 in the deployment environment, or set ALLOW_MISSING_APP_KEY_SHA256=1 for local/dev builds." >&2
        exit 1
    fi
    RENDER_EXTRA="--allow-missing"
fi
python3 "$SCRIPT_DIR/render_assetlinks.py" \
    "$SCRIPT_DIR/public/.well-known/assetlinks.json" $RENDER_EXTRA

cd "$SCRIPT_DIR/../.."
pnpm install --frozen-lockfile
pnpm --filter efa-proto-ts generate
pnpm --filter efa-platform build
