#!/bin/bash
set -e

# Install uv if not available.
if ! command -v uv >/dev/null 2>&1; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# Go to project root.
cd ../..

# Sync git submodules.
git submodule update --init --recursive

# Sync Python dependencies.
uv sync

# Build the site's content
uv run ./x.py build site-manual

# Build the site
cd ./site/manual
pnpm build
