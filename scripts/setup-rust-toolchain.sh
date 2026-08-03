# Usage: source scripts/setup-rust-toolchain.sh
# Expects NATIVE_RUST_TOOLCHAIN_PATH to be set by the Nix shellHook.

if [ -n "${NATIVE_RUST_TOOLCHAIN_PATH:-}" ]; then
  export PATH="${NATIVE_RUST_TOOLCHAIN_PATH}:$PATH"
fi
