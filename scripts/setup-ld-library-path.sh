# Usage: source scripts/setup-ld-library-path.sh
# Expects LD_LIBRARY_PATH_RUNTIME to be set by the Nix shellHook.

if [ -n "${LD_LIBRARY_PATH_RUNTIME:-}" ]; then
  export LD_LIBRARY_PATH="${LD_LIBRARY_PATH_RUNTIME}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

linux_bundle_lib="$PWD/build/linux/x64/debug/bundle/lib"
if [ -d "$linux_bundle_lib" ]; then
  export LD_LIBRARY_PATH="$linux_bundle_lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
