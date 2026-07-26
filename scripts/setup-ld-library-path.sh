# Usage: source scripts/setup-ld-library-path.sh
# Expects LD_LIBRARY_PATH_RUNTIME to be set by the Nix shellHook.

if [ -n "${LD_LIBRARY_PATH_RUNTIME:-}" ]; then
  export LD_LIBRARY_PATH="${LD_LIBRARY_PATH_RUNTIME}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
