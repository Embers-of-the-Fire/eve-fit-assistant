# Build And Test Commands

Prefer `./x --help` and the relevant command's own help over this document if they disagree.
Run commands from the repository root unless a command explicitly says otherwise.

## Formatting, Linting, And Generation

```sh
./x lint                 # full fix/lint/format pass for all languages
./x format               # formatting only; equivalent to ./x lint --no-check
./x generate -f all      # generate all code, then format
```

`lint`, `format`, and the `test` subcommands are change-aware; they restrict their work to
the packages affected by your changes (resolved by `bootstrap/ci/resolve.py` from the
package graph in `bootstrap/ci/registry.py`, closed over dependents):

```sh
./x lint --changed                       # lint only packages changed vs origin/dev
./x lint --changed --base-ref main       # diff against a different ref
./x lint --packages efa_fit,eve_fit_assistant   # explicit package scope
./x format --changed
./x test dart --changed
./x test all --changed
```

Uncommitted (staged, unstaged, and untracked) changes are included in `--changed`.
Changes to the selection system, `flake.nix`/`flake.lock`, or `.github/**` escalate to the
full pass.
Use `uv run x.py ci affected --target <ref>` to inspect the resolution.

Focused generators:

```sh
./x generate protobuf
./x generate rust
./x generate dart
./x generate l10n
./x generate values dogma-units
melos run app:gen        # freezed/JSON model generation for the app
```

## Application Builds

| Target | Command | Output |
| ------ | ------- | ------ |
| Android APK | `melos run app:build:apk` or `./x build apk` | Flutter Android output |
| Linux | `./x build linux` | `cache/releases/linux/<ver>/` |
| Windows | `./x build windows` | `cache/releases/windows/<ver>/` |
| Web | `./x build web` | `apps/eve-fit-assistant/build/web/` |

### Linux Variants

`./x build linux` builds two variants; select a subset with `--variant appimage` or
`--variant native`:

- `appimage` requires `linuxdeploy` and `appimagetool` from the Nix dev shell. linuxdeploy
  resolves and bundles dependent libraries. The glibc loader and its NSS modules are bundled,
  and AppRun launches through the bundled loader. Other libraries, including the graphics
  driver family, resolve from the host at runtime; the Flutter bundle `lib/` directory is
  searched first through `LD_LIBRARY_PATH`.
- `native` is the raw Flutter Linux release bundle zipped as-is.

The command also emits a Linux release fragment (`<ver>-linux.json`) for the release registry.

### Windows Variants

`./x build windows` runs only on a Windows host. It builds two variants; select a subset with
`--variant native` or `--variant installer`:

- `native` is the raw Flutter Windows release bundle zipped as-is.
- `installer` is a per-user multilingual MSI. The en-US base has the zh-CN language transform
  embedded as an LCID-named substorage, automatically applied by Windows Installer on matching
  UI languages. It is built with WiX v6 from `distro/windows/installer/Package.wxs` and
  per-culture `Package.<culture>.wxl` files. It requires the .NET SDK and
  `dotnet tool install --global wix --version 6.0.1`; WiX v7 is excluded because it requires
  accepting the OSMF EULA.

The command also emits a Windows release fragment (`<ver>-windows.json`) for the release
registry. See @docs/agents/environment for the Windows toolchain prerequisites.

### Web Engine Build

The FRB web engine build is:

```sh
flutter_rust_bridge_codegen build-web --release \
  --wasm-pack-rustflags "-C target-feature=+atomics,+bulk-memory,+mutable-globals \
    -Clink-args=--shared-memory -Clink-args=--max-memory=1073741824 \
    -Clink-args=--import-memory -Clink-args=--export=__heap_base \
    -Clink-args=--export=__wasm_init_tls -Clink-args=--export=__tls_size \
    -Clink-args=--export=__tls_align -Clink-args=--export=__tls_base"
```

Run it from `apps/eve-fit-assistant/`. Output lands in gitignored
`apps/eve-fit-assistant/web/pkg/` and is copied into `apps/eve-fit-assistant/build/web` by
`flutter build web`.

The FRB toolchain uses wasm-pack and nightly `-Z build-std` and requires `rust-src` on
nightly. The dev shell provides `wasm-pack` and `binaryen`, so `wasm-opt` resolves locally
instead of downloading from GitHub.

The atomics build lets FRB's web worker pool run engine calls such as database parsing and
emulation in real Web Workers instead of blocking the browser event loop. FRB routes normal
functions (not `#[frb(sync)]` and not `async`) through that pool, so the heavy engine APIs in
`rust/src/api/server.rs` are deliberately normal functions. lld does not enable shared memory
from `+atomics` alone; the shared-memory, import-memory, max-memory, and TLS-export link args
from the wasm-bindgen threading recipe are required so pool workers share one memory instance.

The threaded build requires a cross-origin-isolated origin. `web/_headers` ships
`Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`
for Cloudflare Pages. Local development needs equivalent headers, for example through
`flutter run -d chrome --web-header=...`. Without isolation, the app boots without the native
engine; the probe is `crossOriginIsolated()` in `packages/efa_compat/`.

### Web Bundle Build

Run `./x build web` inside `nix develop .#codegen`. It wraps the web engine build plus:

```sh
flutter build web --wasm --no-web-resources-cdn
```

Canvaskit and skwasm are bundled locally instead of loaded from the gstatic CDN, making the
bundle self-contained. The command then prunes canvaskit artifacts unused by the declared
renderers; pass `--no-prune` to skip pruning.

The localization SQLite web worker ships under `web/sqlite/`: `sqlite3.wasm` from
simolus3/sqlite3.dart releases matching the `sqlite3` version, and `db_worker.js` from
powersync-ja/sqlite_async.dart releases matching `sqlite_async`. Both are copied into
`build/web` and are required for localized names on web.

## Tests

| Scope | Command |
| ----- | ------- |
| All tests | `./x test all` |
| Python | `./x test python` or `uv run pytest` |
| Flutter/Dart | `./x test dart`, `melos run app:test`, or `flutter test` from the app directory |
| Web platform | `./x test web` |
| Repo module | `dart test test/storage/repo/` from the app directory |
| Migration | `dart test test/storage/repo/migration/` from the app directory |
| Bridge crate | `cargo test -p rust_lib_eve_fit_assistant` |
| Fitting engine | `cargo test -p eve-fit-os` |
| Chat crate | `cargo test -p efa-chat` |
| Single Rust integration file | `cargo test -p eve-fit-os --test test_basic_fit -- --nocapture` |
| Single Rust integration test | `cargo test -p eve-fit-os test_basic_fit -- --exact --nocapture` |
| JS/TS (workers) | `./x test js`, `pnpm test:js`, or `pnpm --filter <worker-package> test` |

### JS/TS Test Pipeline

JS/TS tests use [Vitest](https://vitest.dev/) everywhere; `node:test` is not used. The
Cloudflare Workers under `worker/` run their suites inside
[`@cloudflare/vitest-plugin`](https://developers.cloudflare.com/workers/testing/vitest-integration/),
which executes tests in the real `workerd` runtime with genuine local bindings (D1, KV,
Durable Objects) instead of hand-written mocks. Each worker's `vitest.config.ts` loads its
`wrangler.toml`, reads `migrations/` via `readD1Migrations`, and a `test/apply-migrations.ts`
setup file applies them with `applyD1Migrations`; test-only secrets (e.g. `SYNC_TOKEN`,
`AUTH_TOKEN_SECRET`) are declared as plain Miniflare bindings there, not in `.dev.vars`.
Storage isolation is per test file; `reset()` from `cloudflare:test` wipes the whole isolated
storage (including the D1 schema), so per-test cleanup re-applies the migrations afterwards.
Time-dependent tests use `vi.useFakeTimers({ toFake: ["Date"] })` at the endpoint level or
explicit `nowMs` parameters at the helper level.

### Web Test Pipeline

`./x test web` runs headless Chrome through `flutter test --platform chrome`. Chrome resolves
from `CHROME_EXECUTABLE` or `google-chrome`, `chromium`, or `chrome` on `PATH`.

Suites are platform-aware: VM-only suites carry `@TestOn("vm")`, and web-only suites under
`test/web/` carry `@TestOn("browser")`. The web test pipeline compiles every selected suite
regardless of `@TestOn`, so `x.py test web` excludes VM-only suites whose `dart:ffi`-only
imports would fail the web compile and instead passes the explicit web-compatible suite list.

The pipeline compiles to JavaScript, not wasm: the dart2wasm web-test harness cannot run
sqlite3_web in headless Chrome because dedicated workers and OPFS sync access handles are
unavailable there. The JavaScript build exercises the real worker and OPFS path.
`x.py test web` also mirrors `web/sqlite/{db_worker.js,sqlite3.wasm}` into
`test/web/sqlite/` because the web test server serves only the `test/` tree;
`localization_db_web_test.dart` needs those files.

### Dart Test Notes

Data-flow integration tests such as `test/storage/repo/` use `package:mocktail` for network
and filesystem mocks. Async tests require `flutter test` or `dart test` with the Flutter SDK
on `PATH`.

## Release Preflight

Run release preflight checks with:

```sh
./x ci release verify --check-all
```
