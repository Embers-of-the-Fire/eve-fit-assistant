#!/bin/sh
set -e

cd "$(dirname "$0")"

mkdir -p dist

if [ "$CF_PAGES_BRANCH" = "dev" ]; then
    python3 render_assetlinks.py dist/.well-known/assetlinks.json
else
    python3 render_assetlinks.py dist/.well-known/assetlinks.json --allow-missing
fi

cp src/* dist/
cp public/* dist/
