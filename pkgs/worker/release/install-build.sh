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

