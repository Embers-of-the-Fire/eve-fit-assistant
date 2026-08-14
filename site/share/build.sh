#!/bin/sh
set -e

cd "$(dirname "$0")"

if [ "$CF_PAGES_BRANCH" = "dev" ]; then
    python3 render_assetlinks.py static/.well-known/assetlinks.json
else
    python3 render_assetlinks.py static/.well-known/assetlinks.json --allow-missing
fi

cd ../..
pnpm install --frozen-lockfile
pnpm --filter efa-share build

# Cloudflare Pages serves 404.html for unmatched paths; the root page is the
# localized "link not found" state, so reuse it as the 404 body.
cp site/share/.svelte-kit/cloudflare/index.html site/share/.svelte-kit/cloudflare/404.html
