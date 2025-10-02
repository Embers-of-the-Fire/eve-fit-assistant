# EVE Fit Assistant

## Features

> This branch, branch `dev`, is under rapid development.
> If you want to build a stable version of EFA,
> please go to the `main` branch.

EFA is designed to be a cross-platform eve fitting tool
on mobile devices. Besides basic fitting utilities,
the app will also support basic market statistics
and some extra info essential for digging into EVE.

> Currently the target GUI does not
> including tablets but might have a better support
> on extra large screens.

The app is source-insensitive, which means that the
app itself does not care about where the data come
from. However, unlike the sibling project
[EVE Multitools](https://github.com/Embers-of-the-Fire/EVE-Multitools),
EFA wont support integrated multi-datasource as
backend data.

### Platform support

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

### Prerequisites

- A flutter sdk &ge; 3.35 (with dart sdk &ge; 3.9 of course).  
  ```text
  > flutter --version   
  Flutter 3.35.5 • channel stable • https://github.com/flutter/flutter.git
  Framework • revision ac4e799d23 (4 days ago) • 2025-09-26 12:05:09 -0700
  Engine • hash 0274ead41f6265309f36e9d74bc8c559becd5345 (revision d3d45dcf25) (3 days ago) • 2025-09-26 16:45:18.000Z
  Tools • Dart 3.9.2 • DevTools 2.48.0
  ```
- Rust toolchain &ge; 1.90, with NDK if you want to build for Android.
- Python &ge; 3.13 with UV &ge; 0.8 as manager.

After setting up the environment,
run the following command to initialize the workspace:

```bash
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
There're mainly two types of configuration files:
- Toml files, which are checked in the repo.
  These files are used to configure the build process regardless
  of the environment.
- Env files, which are not checked in the repo.
  These files are used to configure the build process,
  but vary in different environments.

Any configuration file comes with a template file:
- `.env` -> `.env.example`
- `efa.config.toml` -> `efa.config.example.toml`
- `data/resources/*/descriptor.toml` -> `data/resources/example/descriptor.toml`.

**Important**:
The backend engine, `eve-fit-os` uses `.env` files to generate
data and compile the rust code.
However, that project is not configured to support multi-datasource.
To solve this problem, the build CI/CD will internally write some
variables to the environment when building the backend.
But, as the LSP and linter need to build the backend too,
you need to manually write mock variables to your local `.env` file.
For this project, we suggest you to use the `tranquility` datasource
for local development, which means the `rust/lib/eve-fit-os/.env` file
should look like this:

```env
FSD_BINARY_DIR=/home/admin/develop/eve-fit-assistant/data/resources/tranquility/fsd
FSD_FORMAT=msgpack
FSD_LOC_EN_DIR=/home/admin/develop/data/bundle-cache/tq/index-cache/resources/localizationfsd/localization_fsd_en-us.pickle
OUTPUT_DIR=/home/admin/develop/eve-fit-assistant/data/resources/tranquility/out
```

### Build

1.  Generate localization (if you've edited them).
    ```bash
    flutter gen-l10n
    ```
2.  Generate backend data. For more information, see [data readme](./data/README.md).
3.  - Build APK (for Android)
      ```bash
      flutter build apk
      ```
    - Build IPA (for iOS)  
      Go to the official flutter documentation for more information.

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

If you want to or have to use a new cmdline operation,
you can add a new subcommand to the manager instead.
