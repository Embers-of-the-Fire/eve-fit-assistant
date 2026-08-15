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

# If you used the command above:
unzip $(basename $URL) -d $HOME/.local

