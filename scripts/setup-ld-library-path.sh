# Usage: source scripts/setup-ld-library-path.sh
# Expects LD_LIBRARY_PATH_RUNTIME to be set by the Nix shellHook.

# NOTE: The Flutter Linux debug bundle lib dir (build/linux/x64/debug/bundle/lib)
# is intentionally NOT added here. Its bundled libsqlite3.so is a trimmed build
# that lacks exported symbols such as sqlite3_limit, and because LD_LIBRARY_PATH
# takes precedence over the Nix python's DT_RUNPATH, exposing it to the shell
# broke every Python process that imports sqlite3 (e.g. `./x build data`).
# `flutter run -d linux` sets the app's own LD_LIBRARY_PATH.

if [ -n "${LD_LIBRARY_PATH_RUNTIME:-}" ]; then
  export LD_LIBRARY_PATH="${LD_LIBRARY_PATH_RUNTIME}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
