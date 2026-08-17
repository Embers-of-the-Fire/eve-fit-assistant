#!/bin/bash
set -e

# Install Rust via rustup (non-interactive)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Load cargo into the current shell session
. "$HOME/.cargo/env"

# Add the WebAssembly target required for Workers
rustup target add wasm32-unknown-unknown

# Install the Workers Rust build tool
cargo install -q "worker-build@^0.8"

# Install protoc
# Fetch the download URL for the latest Linux x86_64 asset from GitHub API
URL=$(curl -s https://api.github.com/repos/protocolbuffers/protobuf/releases/latest \
  | jq -r '.assets[] | select(.name | endswith("linux-x86_64.zip")) | .browser_download_url')
curl -LO $URL
unzip $(basename $URL) -d $HOME/.local

# Resolve the repository root (this script lives in worker/efa-platform-fit-storage)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# The fitting engine is a git submodule
git -C "$REPO_ROOT" submodule update --init packages/eve-fit-os

# PyYAML is needed by gen_engine_json.py; the Cloudflare builder has python3
# but no project environment.
python3 -c 'import yaml' 2>/dev/null || pip install --user pyyaml

# Generate the negative-only patch JSONs the engine's build.rs requires.
python3 "$REPO_ROOT/worker/efa-platform-fit-storage/gen_engine_json.py"

# The engine's build.rs unconditionally requires .env + OUTPUT_DIR, even with
# default-features = false. Never overwrite an existing .env (developer
# machines have a real one written by `./x dev env write-backend`).
if [ ! -f "$REPO_ROOT/packages/eve-fit-os/.env" ]; then
  echo "OUTPUT_DIR=$REPO_ROOT/worker/efa-platform-fit-storage/engine-json" \
    > "$REPO_ROOT/packages/eve-fit-os/.env"
fi
