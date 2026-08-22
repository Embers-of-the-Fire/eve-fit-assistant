# Environment And Setup

## Development Shell

Use `nix develop` on Linux. `flake.nix` supplies Flutter, JDK 17, Android SDK/NDK, Rust and
Cargo, `uv`, protobuf tools, `flutter_rust_bridge_codegen`, and the Linux packaging tools.
Treat `flake.nix` as the environment source of truth.

Bootstrap dependencies with:

```sh
./x dev env install
```

The equivalent inside the dev shell is `flutter pub get` plus `uv sync`.

## Local Configuration

- Python requires 3.13+ and is managed by `uv`. Run the workspace CLI through `./x`,
  `./x.ps1`, or `uv run x.py`, not through a global Python interpreter.
- Backend Rust builds, tests, and code generation need `packages/eve-fit-os/.env`. Normally
  create `efa.dev.toml` with `./x dev init-cfg`, set `[native]`, then run
  `./x dev env write-backend`.
- Do not hand-edit `apps/eve-fit-assistant/android/local.properties` unless necessary. The
  Nix shell hook regenerates it with only SDK, NDK, and CMake paths derived from the Nix
  environment. Flutter build properties such as version and build mode are not touched; they
  are read from the app's `pubspec.yaml` directly.
- Windows has no Nix toolchain. For Windows builds, `flutter`, `cargo`, `protoc`, `dotnet`,
  and `wix` must be on `PATH`, and the Visual Studio C++ ATL component
  (`Microsoft.VisualStudio.Component.VC.ATL`, providing `atlstr.h` for
  `flutter_secure_storage_windows`) must be installed.

## External Data Prerequisites

Generated data depends on external EVE FSD/resource files described by
`data/resources/*/descriptor.toml`. Missing local resources can block data builds. Data
workspace selection and build commands are documented in @docs/agents/data-versioning.
