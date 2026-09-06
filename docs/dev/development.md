# Development Guide

This guide covers setting up a local development environment and building EFA
from source. If you only want to use EFA, see the [root README](../../README.md)
or the [user manual](https://docs.efa-tech.dev) instead.

## Development Tools

It's recommended to use [Android Studio](https://developer.android.com/studio),
but you can also try [Visual Studio Code](https://code.visualstudio.com/).

The repository contains some configurations for both editors for easier development.

## Prerequisites

- Nix with flakes enabled (x86_64 Linux only). The repository `flake.nix`
  provides Flutter, JDK 17, Android SDK/NDK, Rust/Cargo, Python, `uv`,
  protobuf tooling, and FRB codegen.
- If you do not use Nix, provide equivalent Flutter/Dart, Android, Rust, Python,
  `uv`, protobuf, and `flutter_rust_bridge_codegen` tooling yourself.
- iOS builds additionally require macOS with Xcode. Follow the official
  [Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup)
  to prepare the environment.

After setting up the environment,
run the following command to initialize the workspace:

```bash
nix develop      # enter the preferred development shell
flutter pub get  # init flutter
uv sync          # init python
```

> Note: Lock files (`pubspec.lock`, `uv.lock`, `Cargo.lock`) are checked in.
> If you use a mirror for package registries, you may need to regenerate them.

## Configure

Before building the app, you need to do some configuration.

The app uses multiple configurations files to manage the build.
There're mainly three types of configuration files:

- Toml files, which are checked in the repo.
  These files are used to configure the build process regardless
  of the environment.
- Dev Toml files, which are not checked in the repo.
  These files configure local paths, private settings, and developer shortcuts.
- Env files, which are not checked in the repo.
  These files are kept for tools that still read dotenv files directly.

Any configuration file comes with a template file:

- `.env` -> `.env.example`
- `efa.config.toml` -> `efa.config.example.toml`
- `efa.dev.toml` -> `efa.dev.example.toml`
- `data/resources/*/descriptor.toml` -> `data/resources/example/descriptor.toml`.

**Version Control**:
The `efa.config.toml` is checked in, which means changing server
support is also viewed as a breaking change.
The `efa.dev.toml` is private local configuration and must not be checked in.
It owns local mutable paths such as logs and workspace build/cache output.
Only `paths.root` is configurable; the sub-root layout is fixed.
For example, if `efa.dev.toml` sets `paths.root = "cache"`, then workspace
state is placed under `./cache/workspaces/tranquility`,
`./cache/workspaces/serenity`, and so on, while logs are placed under
`./cache/log`.

**Important**:
The backend engine, `eve-fit-os` still uses `.env` files to generate
data and compile the rust code.
However, that project is not configured to support multi-datasource.
To solve this problem, the build CI/CD will internally write some
variables to the environment when building the backend.
But, as the LSP and linter need to build the backend too,
you need local mock variables for backend builds.
Set the `[native]` section in `efa.dev.toml`, then run:

```bash
./x dev env write-backend
```

For this project, we suggest you to use the `tranquility` datasource
for local development, which means the generated `packages/eve-fit-os/.env`
file should look like this:

```env
FSD_BINARY_DIR=/path/to/repo/data/resources/tranquility/fsd
FSD_FORMAT=msgpack
FSD_LOC_EN_DIR=/path/to/repo/cache/workspaces/tranquility/index-cache/resources/localizationfsd/localization_fsd_en-us.pickle
OUTPUT_DIR=/path/to/repo/cache/workspaces/tranquility/native
```

## Build

Generate code and localization after schema, FRB, Dart model, or l10n changes.

```bash
./x generate -f all
```

Generate backend data. For more information, see [data readme](../../data/README.md).

```bash
./x workspace list
./x workspace default <workspace>
./x build data
```

Build APK for Android.

```bash
flutter build apk
```

Build IPA for iOS (requires macOS with Xcode; see the
[official Flutter documentation](https://docs.flutter.dev/deployment/ios) for
signing and distribution details):

```bash
flutter build ipa
```

## Management

The project uses a built-in Python script, [`x.py`](../../x.py) to manage the workspace.

You can run `uv run x.py`, `./x` (bash environment) or `./x.ps1` (powershell environment)
to run the script.

> Hint: running `./x` within powershell sometimes works thanks to bash-like aliases,
> but sometimes it doesn't. If you encounter any problem,
> please use `./x.ps1` instead.

Note that it's not recommended to run the script using the global python interpreter,
as the script may depend on some packages only installed in the uv environment.

For more information about the manager, run `./x --help` to see the help message,
or just read the source code of `x.py`.

The X manager is designed to replace any specific command line operations
you may want to do during development.
For example, you can run `./x lint` to lint the whole project.

Common manager commands:

- `./x dev init-cfg`: copy `efa.dev.example.toml` to `efa.dev.toml`.
- `./x dev env install`: install project dependencies for local development.
- `./x dev env write-backend`: generate the backend `.env` from `efa.dev.toml`.
- `./x lint`: run the canonical fix, lint, and format pass.
- `./x format`: format project sources without lint checks.
- `./x generate -f all`: regenerate protobuf, Rust bridge, Dart-generated files,
  and localization, then format.
- `./x generate protobuf`: regenerate Python and Dart protobuf outputs.
- `./x generate rust`: regenerate Flutter Rust Bridge glue.
- `./x generate dart`: run Dart `build_runner` codegen.
- `./x generate l10n`: regenerate localization files.
- `./x build data`: build the selected workspace data.

If you want to or have to use a new cmdline operation,
you can add a new subcommand to the manager instead.

## Dev-Only Environment

You can set local developer defaults in `efa.dev.toml` to simplify the development process.
It's strongly not recommended to use these values in production builds.

See [`efa.dev.example.toml`](../../efa.dev.example.toml) for more information.

## Data Build Routine

When you need to build data:

1. Select the target workspace with `./x workspace default <workspace>` if needed.
2. Build with `./x build data`.
3. Build artifacts are placed in the workspace's generated directory, while the
   V2 schema snapshot is written separately under `<paths.root>/schema`:
   resource snapshots at `schema/assets/resources/<hash>/` (containing
   `metadata.json` and `resources.pb2`) and content-addressed blobs at
   `schema/assets/blobs/...`.

### Hack through workspace management

You may want to test different data sources during development,
while not wanting to modify the default workspace selection.
You can hack through the workspace management system
by adding `--workspace/--ws` when calling `x.py`:

```bash
./x --ws serenity build data
```
