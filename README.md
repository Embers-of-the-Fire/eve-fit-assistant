# EVE Fit Assistant

## Overview

> This branch, branch `dev`, is under rapid development.
> If you want to build a stable version of EFA,
> please go to the `main` branch.

EFA is designed to be a cross-platform EVE fitting tool
for mobile devices. The current alpha focuses on local fit editing,
bundle-backed static data, item detail inspection, and character skill profiles.
Market statistics and broader EVE reference tools remain planned scope.

> Currently the target GUI does not
> including tablets but might have a better support
> on extra large screens.

The app is source-insensitive, which means that the
app itself does not care about where the data come
from. However, unlike the sibling project
[EVE Multitools](https://github.com/Embers-of-the-Fire/EVE-Multitools),
EFA wont support integrated multi-datasource as
backend data.

### Platform Support

EFA guarantees support for Android and partial support
for Android-based systems and will release officially
built bundles for Android.

EFA supports building bundles targeting iOS but will not
test and offer pre-built binaries for that platform.
If you want to use EFA on iOS, you have to build
the app yourself following [this guide](#build).

## Architecture

EFA is a multi language project containing
the following techs:

- Flutter(and dart): The infrastructure to build the frontend.
- Rust(via [`flutter_rust_bridge`](https://github.com/fzyzcjy/flutter_rust_bridge)):
  The fitting backend is implemented in Rust.
  See [`eve-fit-os`](https://github.com/Embers-of-the-Fire/eve-fit-os) for more information.
- Python: Python is not used inside the app, but is used to process the data.

The app is built with two layer, the frontend (flutter) and the backend (rust).
The backend is used to calculate statistics of a fit and won't interfere
with frontend render and display.
The frontend is used to display everything,
including interactions with the backend.

## Development

### Development Tools

It's recommended to use [Android Studio](https://developer.android.com/studio),
but you can also try [Visual Studio Code](https://code.visualstudio.com/).

The repository contains some configurations for both editors for easier development.

### Prerequisites

- Nix with flakes enabled. The repository `flake.nix` provides Flutter, JDK 17,
  Android SDK/NDK, Rust/Cargo, Python, `uv`, protobuf tooling, and FRB codegen.
- If you do not use Nix, provide equivalent Flutter/Dart, Android, Rust, Python,
  `uv`, protobuf, and `flutter_rust_bridge_codegen` tooling yourself.

After setting up the environment,
run the following command to initialize the workspace:

```bash
nix develop      # enter the preferred development shell
flutter pub get  # init flutter
uv sync          # init python
```

> Note: This project is mainly targeting Chinese users, so
> all of the registries are configured to use a mirror.
> You may want to ignore the lock files
> (`pubspec.lock`, `uv.lock`, `Cargo.lock`, etc.).

### Configure

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
for local development, which means the generated `rust/lib/eve-fit-os/.env`
file should look like this:

```env
FSD_BINARY_DIR=/home/admin/develop/eve-fit-assistant/eve-fit-assistant/data/resources/tranquility/fsd
FSD_FORMAT=msgpack
FSD_LOC_EN_DIR=/home/admin/develop/eve-fit-assistant/eve-fit-assistant/cache/workspaces/tranquility/index-cache/resources/localizationfsd/localization_fsd_en-us.pickle
OUTPUT_DIR=/home/admin/develop/eve-fit-assistant/eve-fit-assistant/cache/workspaces/tranquility/native
```

### Build

Generate code and localization after schema, FRB, Dart model, or l10n changes.

```bash
./x generate all -f
```

Generate backend data. For more information, see [data readme](./data/README.md).

```bash
./x workspace list
./x workspace default <workspace>
./x build data
```

Build APK for Android.

```bash
flutter build apk
```

Build IPA for iOS by following the official Flutter documentation.

### Management

The project uses a builtin Python script, [`x.py`](./x.py) to manage the workspace.

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
- `./x generate all -f`: regenerate protobuf, Rust bridge, Dart generated files,
  and localization, then format.
- `./x generate protobuf`: regenerate Python and Dart protobuf outputs.
- `./x generate rust`: regenerate Flutter Rust Bridge glue.
- `./x generate dart`: run Dart `build_runner` codegen.
- `./x generate l10n`: regenerate localization files.
- `./x build data`: build the selected workspace data bundle.
- `./x build data --no-hash`: build data without updating snapshot manifests for
  faster local iteration.
- `./x build increment <baseline_manifest>`: build a strict incremental patch bundle.

If you want to or have to use a new cmdline operation,
you can add a new subcommand to the manager instead.

### Dev-Only Environment

You can set local developer defaults in `efa.dev.toml` to simplify the development process.
It's strongly not recommended to use these values in production builds.

See [`efa.dev.example.toml`](./efa.dev.example.toml) for more information.

- `build.skip_hash`: A shortcut default for `x build data --no-hash`.
  This disables snapshot manifest generation, so incremental patch bundles cannot be produced from that build output.
- `build.baseline`: A shortcut default for `x build inc <BASELINE_MANIFEST>`.
  This sets the default baseline manifest path used for incremental patch builds.

Full data builds now emit `bundle_manifest.json` beside the bundle archive.
Incremental builds are strict patch bundles: they require a compatible installed base bundle,
carry only changed files plus deletions, and update `bundle_manifest.json` to the new snapshot.

### Data Bundle Routine

When you need to publish a new full data bundle:

1. Select the target workspace with `./x workspace default <workspace>` if needed.
2. Build the full bundle with `./x build data`.
3. Collect the two output artifacts from the workspace output directory:
   - `<bundle_id>.zip`
   - `bundle_manifest.json`
4. Treat `bundle_manifest.json` as the baseline manifest for the next patch build.

When you need to publish a new incremental data patch:

1. Start from a workspace that already has a fresh full generated snapshot.
2. Keep the previous published `bundle_manifest.json` from the base bundle or base patch.
3. Rebuild the current data state if needed with `./x build data`.
4. Build the patch with `./x build increment <BASELINE_MANIFEST>`.
5. Collect the new output artifacts from the workspace output directory:
   - `<bundle_id>_increment.zip`
   - `bundle_manifest.json`
6. Publish the new `bundle_manifest.json` together with the patch, because it becomes the baseline for the next patch.

Important rules:

- Full bundles are standalone; incremental patches are not.
- An incremental patch can only be imported onto an installed bundle with the matching baseline manifest.
- If you run `./x build data --no-hash` or set `EFA_SKIP_FULL_MANIFEST_UPDATE=true`, the build will not produce a usable baseline manifest for patch generation.
- Always keep the manifest that was published with the last accepted bundle state; that is the input for the next patch build.

#### Hack through workspace management

You may want to test different data sources during development,
while not wanting to modify the default workspace selection.
You can hack through the workspace management system
by adding `--workspace/--ws` when calling `x.py`:

```bash
./x --ws serenity build data
```

## Languages

![codeart](./codeart.png)
