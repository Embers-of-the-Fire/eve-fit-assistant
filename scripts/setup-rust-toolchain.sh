# Usage: source scripts/setup-rust-toolchain.sh
# Expects NATIVE_RUST_TOOLCHAIN_PATH to be set by the Nix shellHook.

if [ -n "${NATIVE_RUST_TOOLCHAIN_PATH:-}" ]; then
  export PATH="${NATIVE_RUST_TOOLCHAIN_PATH}:$PATH"
fi

if command -v rustup &>/dev/null; then
  if ! rustup target list --installed 2>/dev/null | grep -q wasm32-unknown-unknown; then
    rustup target add wasm32-unknown-unknown --toolchain stable 2>/dev/null || true
  fi
fi
