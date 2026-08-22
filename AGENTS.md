# AGENTS.md

Compact repo guidance for future OpenCode sessions. Prefer executable config and `./x --help` over stale prose if anything conflicts.

Detailed subsystem docs live in `docs/agents/` (index: @docs/agents/README) and are referenced from the relevant sections below with `@docs/agents/...` links.

## Overall Guideline

- You *MUST* always fetch official documentations as the source of truth. *DO NOT* use your world knowledge.
- For every assumptions or conclusions that made without accessing docs, you *MUST* give a URL to prove your words.

## Workspace Shape

- The Flutter/Dart app lives in `apps/eve-fit-assistant/`, managed as a melos pub workspace (root `pubspec.yaml` is the workspace root; Flutter-scoped tasks — tests, analyze, format, build_runner, l10n, platform builds — are melos `app:*` scripts there, and `./x` delegates to them). Generated Dart outputs include `lib/native/`, `lib/data/l10n/`, `*.g.dart`, and `*.freezed.dart` (app-relative).
  - `apps/eve-fit-assistant/lib/storage/repo/` implements a content-addressed repository system for data versioning with checkout-based data management and diff chains.
- `packages/efa_proto/` hosts the Dart protobuf bindings generated from the `.proto` sources in `data/schema/` (via `./x generate protobuf`), imported as `package:efa_proto/<name>.pb.dart`. The Python bindings stay in `bootstrap/data/schema/` (top-level `<name>_pb2` modules on `sys.path`). All generated files are gitignored — never check them in.
- `packages/efa_proto_ts/` hosts the TypeScript protobuf bindings (protobuf-es, runtime `@bufbuild/protobuf`) for the platform-facing fit schemas (`utils`, `fit`, `fit_snapshot`, `fit_request`), imported as `efa-proto-ts/<name>_pb`. Generated into the gitignored `src/gen/` by `./x generate protobuf` (or `pnpm --filter efa-proto-ts generate`) via `buf` (npm binary, no protoc needed) using `buf.gen.yaml` — the schema list lives there.
- `packages/efa_constant/` hosts the dependency-free EVE constant definitions (`package:efa_constant/eve.dart`: `EveConst*` classes, `EveDogmaUnitId` enum). `eve_dogma_unit_generated.dart` is tracked (via `./x generate values dogma-units`); `eve_attr_generated.dart` is generated and gitignored.
- `packages/efa_fit/` hosts the shared fit format logic (`package:efa_fit/efa_fit.dart`): the EFA(n) native payload codecs (versioned JSON envelope → gzip → base64/base64url with `EFA<n>:` prefix, size caps, `EfaFitFormatException`), the EFT-compatible text format (`parseEft`/`formatEft` over the neutral `EftFit` model with an injected `EftTypeResolver`/`EftTypeNameLookup` for name and slot resolution), and fit link construction/parsing (`buildFitLinkShareUrl`, `parseFitLinkUri`, `parseFitLinkBootUri`, hosts/scheme constants). Pure Dart (only depends on `archive`); the app keeps the `FitStorage` model and maps to/from these formats. Tests run via `melos run pkg:test`.
- Rust has three crates: FRB bridge crate in `apps/eve-fit-assistant/rust/` (`rust/src/api/*`), the fitting engine git-submodule crate in `packages/eve-fit-os`, and the AI chat crate in `apps/eve-fit-assistant/rust/lib/efa-chat` (see @docs/agents/efa-chat). The root `Cargo.toml` is the cargo workspace root.
- Python in `bootstrap/` plus `x.py` owns workspace management, codegen orchestration, and static data packaging. The top-level `data/` directory holds only raw EVE resources (`data/resources/`) and protobuf `.proto` schema sources (`data/schema/`).
- `apps/eve-fit-assistant/rust_builder/` is the Flutter plugin/cargokit wrapper used by the app's `pubspec.yaml`; avoid treating it as the main Rust source.
- `site/` is a SvelteKit app deployed to Cloudflare Workers (pnpm workspace). `biome.json` governs JS/TS formatting/linting for this area. `site/platform/` is the exception: an Astro 7 + Svelte-islands SSR app (discussion platform, Cloudflare Worker `efa-platform` with static assets at `platform.efa-tech.dev` plus the legacy fit-link host `share.platform.efa-tech.dev`, deployed via `wrangler deploy --config dist/server/wrangler.json`) using `@astrojs/cloudflare` v14 (`import { env } from "cloudflare:workers"`, `Astro.locals.cfContext`, global `caches`), Tailwind v4, a D1 binding (`FIT_DB` → `efa-platform`, shared with `worker/efa-platform-fit-storage`), Astro server endpoints under `src/pages/api/`, and Astro 7 route caching via the Cloudflare CDN cache provider (`cache: { provider: cacheCloudflare() }` in `astro.config.mjs`; `routeRules` is deliberately scoped to the single SSR-content route `/post/[id]` (`{ maxAge: 31536000, swr: 86400 }`) — list/account pages are data-free shells whose islands fetch live data client-side and must stay uncached; the post page opts out via `Astro.cache.set(false)` on its 404 branch). The adapter auto-enables Workers Cache in the generated `dist/server/wrangler.json`, whose keys include the Worker version by default, so every deploy automatically invalidates cached HTML (never set `cross_version_cache`); uncached routes default to `no-store`; `/_astro/*` assets get immutable headers via the adapter-emitted `dist/client/_headers`. It also hosts the fit-share landing page (`/share/fit/raw`, see the App Links section) and renders `public/.well-known/assetlinks.json` at build time.
- UI work across app and sites follows the cross-product design principles in @docs/agents/style and the canonical color system in @docs/agents/color (brand surfaces keep the homepage palette; workload platforms — app, share, discussion — share one palette).
- `packages/eve-fit-os` is a Git submodule; run `git submodule update --init` after clone if not already initialized.

Throughout this document, app paths written as `lib/...`, `test/...`, `rust/...`, `l10n/...`, or `web/...` are relative to `apps/eve-fit-assistant/` unless stated otherwise.

## Storage Layer

| System | Path | Description |
| -------- | ------ | ------------- |
| Repo System | `lib/storage/repo/` | Content-addressed repository implementing the EFA V2 unified storage schema (generation-based, protobuf-driven) with blob store, resource snapshots, channel discovery, checkout lifecycle, and Riverpod providers. |
| Schema Version | `lib/storage/repo/schema_version.dart` | `SchemaVersionService` — reads/writes `schema_version.json`, determines active storage system |
| Channel Discovery | `lib/storage/repo/channel_service.dart` | `ChannelService` — fetches channel registry, head metadata, server index; update detection |
| Checkout Management | `lib/storage/repo/checkout_registry_service.dart` | `CheckoutRegistryService` — manages `checkouts/checkouts.json`, active checkout pointer, reactive stream |
| Checkout Lifecycle | `lib/storage/repo/checkout_service.dart` | `CheckoutService` — checkout CRUD, reflog management, resource fetch orchestration |
| Release Sync | `lib/storage/repo/release_sync.dart` | `ReleaseSyncService` — detects newer app versions against the remote release index via `ReleaseIndex` protobuf (detection only) |
| Generation Navigation | `lib/storage/repo/generation_nav.dart` | `GenerationNavigationService` — channel → server browser for setup page |
| Repo Collection | `lib/storage/repo/collection.dart` | `RepoCollectionService` — sole structural type-data source; pre-loads type data (ships, skills, items, icons) from active checkout's ResourceIndex. |
| Localization DB | `lib/storage/repo/localization_db.dart` | `LocalizationDbService` — lazy localized-string lookups backed by the checkout's prebuilt SQLite `localization.db` (sqlite_async). Native opens the content-addressed blob read-only; web copies the blob once (per content hash) into sqlite3_web's OPFS path and opens it in a web worker (requires cross-origin isolation). `localizedNameProvider` resolves `(id, locale)` on demand. |
| Checkout DB Transport | `lib/storage/repo/checkout_db*.dart` | Shared transport for prebuilt checkout SQLite databases: `CheckoutDbSpec` (resource id, OPFS name prefix, schema version, label) + native read-only open / web OPFS-copy + worker open + `meta.schema_version` check. |
| Agent Resource DB | `lib/storage/repo/agent_resource_db.dart` | `AgentResourceDbService` — `agent_resource.db` (FORCE resource) backing AI chat tools; `type_names(locale, id, value, group_id, category_id, slot_index, slot_kind)` (schema v2) holds localized names keyed by real type id plus group/category and implant/booster slot metadata for `search_items`. Hard dependency: open/provider throw when absent or schema-mismatched. |
| Migration Layer | `lib/storage/repo/migration/` | `action/` — `MigrateService` (orchestrator: fits→characters→finalize), `MigrateFits` (v2→v3 upgrade with `CheckoutRef`), `MigrateCharacters` (v2→v3 upgrade with `CheckoutRef`), `MigrateProgress` (freezed checkpoint state machine + `MigrateProgressStore`, persisted to `.migration_progress.json`), `MigrateFitsResult`/`MigrateCharactersResult` (migration result types). |
| Persistence | `lib/storage/fit/`, `lib/storage/character/` | Fit/character storage schemas; fit supports storageVersion 3 with CheckoutRef |
| Settings | `lib/storage/setting/` | User settings including remote content and platform account configuration |
| Account/Auth | `lib/features/account/` | Platform auth client (`{origin}/platform/auth/*`: signup/signup-resend/verify/login/refresh/logout/deregister/reset), secure-storage session store (`AccountTokenStore` — the session is one JSON document under a single key for atomic rotation writes, with a legacy per-field read fallback; it also holds the developer Cloudflare Access `cf-access-token`), and the Riverpod `AccountController` (rotates the session once per cold start via eager instantiation in `initWithRef`; all read-refresh-write and session-mutating flows run inside a session mutex that re-reads the stored session in the critical section); UI under `lib/pages/setting/account/` (entry tile on the settings tab) |
| Storage FS | `lib/storage/fs/` | Platform storage abstraction: `DocStore`/`BlobStore` interfaces with File (native) and Hive/OPFS (web) backends; `createUserDocStore`/`createRepoBlobStore` factories route settings, fits, characters, announcements, feedback, and version state to the right backend. |

All writes to `checkouts.json` are mutex-guarded; reads are lock-free. The checkout registry provides a reactive stream for live UI updates.

The `RepoStateNotifier` initializes asynchronously at startup; `SchemaGuard` watches the state and renders appropriate screens. `MigrationGate` checks for v1 data remnants and offers a one-time migration prompt before the repo system activates.

### Data-Flow Orchestration

| Workflow | Entry Point | Service |
| ---------- | ------------ | --------- |
| Channel discovery | `discoverChannels()` | `RepoService` → `ChannelService.discoverChannels()` |
| Resource fetch | `fetchResourcesForActiveCheckout()` | `RepoService` → `CheckoutService.fetchResourcesForCheckout()` |
| Create checkout | `createCheckout()` | `RepoService` → `CheckoutService.createCheckout()` |
| Revert | `revertActiveCheckoutTo()` | `RepoService` → `CheckoutService.revertCheckoutTo()` |
| Checkout resolution | `resolveCheckoutRefAsync()` | `RepoService` → `CheckoutResolver.resolveAsync()` |
| Update discovery | `checkForUpdates()` | `RepoService` → `ChannelService.hasUpdates()` |
| Verification repair | `verifyAndRepair()` | `RepoService` → `VerificationService.repairAll()` |
| Checkout lifecycle | `switchActiveCheckout()` / `deleteCheckout()` | `RepoService`
| Prune | `prune()` | `RepoService` → `VerificationService.prune()` |
| Startup recovery | `recoverPartialDownloads()` | `RepoService` (called from `ensureInitialized()`) |

## App Links

Fit deep links (`efa://fit/raw?payload=...` plus HTTPS links on `platform.efa-tech.dev` (`/share/fit/raw`, canonical) and the legacy hosts `share.platform.efa-tech.dev`, `app.efa-tech.dev`, and `app-preview.efa-tech.dev` (`/fit/raw`)) live in `lib/features/fit_link/`: payload codec and URI grammar come from `package:efa_fit/efa_fit.dart` (base64url+gzip over the versioned envelope from `encodeNativeFitPayload` in `lib/storage/fit/persistence.dart`), import (`importer.dart` → `FitManager.importFit`), share-URL builder (`share_link.dart`, used by the export dialog's Copy link action), web boot probe (`boot_probe*.dart`, scrubs the payload from the address bar), OS intake (`native_intake.dart`, via `app_links`), and the consuming widget (`intake_gate.dart`, wired in `main.dart` next to the other gates; awaits repo readiness, imports, then pushes `FitRoute`). Web keeps the hash URL strategy; `web/_redirects` serves the SPA at `/fit/*` and the boot probe reads `Uri.base`. Android intent filters (custom scheme + one autoVerify App Links filter per host) are in `AndroidManifest.xml`; Windows registers `efa://` per-user in `distro/windows/installer/Package.wxs`; Linux declares `x-scheme-handler/efa` in `distro/linux/appimage/efa.desktop` (best-effort). `assetlinks.json` is rendered from `site/platform/assetlinks.template.json` by `site/platform/render_assetlinks.py` (stdlib-only, reads `APP_KEY_SHA256`): `x build web` renders it for the app hosts, and `site/platform/build.sh` renders it into `public/.well-known/` so the platform Worker serves it on both `platform.efa-tech.dev` and `share.platform.efa-tech.dev`. The share landing page is part of `site/platform/` at `/share/fit/raw` (SSR route `src/pages/share/fit/raw.astro` + the `FitShareLanding` Svelte island; kept on-demand rather than prerendered so response headers apply, marked `no-store` with `Referrer-Policy: no-referrer` and `frame-ancestors 'none'`; the island never decodes the payload, only validates the `EFA2:` envelope shape and forwards it to `efa://fit/raw` or the web apps' `/fit/raw`). The legacy share host stays attached to the same Worker solely to keep serving `/.well-known/assetlinks.json` for App Links verification of older app versions; an account-level Cloudflare Bulk Redirect (managed outside this repo) permanently redirects `share.platform.efa-tech.dev/fit/raw` to `https://platform.efa-tech.dev/share/fit/raw` with the query string preserved.

## Environment And Setup

- Use `nix develop`; `flake.nix` supplies Flutter, JDK 17, Android SDK/NDK, Rust/Cargo, `uv`, protobuf tools, and `flutter_rust_bridge_codegen`.
- Bootstrap with `./x dev env install` or, equivalently, `flutter pub get` and `uv sync` inside the dev shell.
- Do not hand-edit `apps/eve-fit-assistant/android/local.properties` unless needed; the Nix shell hook regenerates it with only SDK/NDK/CMake paths derived from the Nix environment. Flutter build properties (version, build mode, etc.) are not touched and are read from the app's `pubspec.yaml` directly.
- Python requires 3.13+ and is managed by `uv`; run `x.py` through `./x`, `./x.ps1`, or `uv run x.py`, not a global Python.
- Backend Rust builds/tests/codegen need `packages/eve-fit-os/.env`; normally create `efa.dev.toml` with `./x dev init-cfg`, set `[native]`, then run `./x dev env write-backend`.

## Canonical Commands

- Full fix/lint/format pass (all languages): `./x lint`.
- Formatting only: `./x format` (`./x lint --no-check`).
- Generate all code and then format: `./x generate -f all`.
- Focused generators: `./x generate protobuf`, `./x generate rust`, `./x generate dart`, `./x generate l10n`, `./x generate values dogma-units`.
- Android build: `melos run app:build:apk` (or `./x build apk` from the workspace CLI).
- Linux build: `./x build linux` (output in `cache/releases/linux/<ver>/`) builds two variants: `appimage` (requires `linuxdeploy` and `appimagetool` from the Nix dev shell; linuxdeploy resolves and bundles dependent libs, and the glibc loader plus its NSS modules are bundled — the AppRun launches through the bundled loader — while all other libraries (including the graphics-driver family) are resolved from the host at runtime; the Flutter bundle `lib/` dir is searched first via `LD_LIBRARY_PATH`) and `native` (the raw Flutter Linux release bundle zipped as-is). Use `--variant appimage` / `--variant native` to select a subset. The command also emits a linux release fragment (`<ver>-linux.json`) for the release registry.
- Windows build: `./x build windows` (Windows host only; output in `cache/releases/windows/<ver>/`) builds two variants: `native` (the raw Flutter Windows release bundle zipped as-is) and `installer` (a per-user multi-language MSI — en-US base with the zh-CN language transform embedded as an LCID-named substorage, auto-applied by Windows Installer on matching UI languages — built with the WiX v6 toolset from `distro/windows/installer/Package.wxs` plus per-culture `Package.<culture>.wxl` files; requires the .NET SDK plus `dotnet tool install --global wix --version 6.0.1` — WiX v7 is excluded because it requires accepting the OSMF EULA). Use `--variant native` / `--variant installer` to select a subset. The command also emits a windows release fragment (`<ver>-windows.json`) for the release registry. There is no Nix toolchain on Windows: `flutter`, `cargo`, `protoc`, `dotnet`, and `wix` must be on PATH, and the Visual Studio C++ ATL component (`Microsoft.VisualStudio.Component.VC.ATL`, providing `atlstr.h` required by `flutter_secure_storage_windows`) must be installed.
- Web engine (wasm) build: `flutter_rust_bridge_codegen build-web --release --wasm-pack-rustflags "-C target-feature=+atomics,+bulk-memory,+mutable-globals -Clink-args=--shared-memory -Clink-args=--max-memory=1073741824 -Clink-args=--import-memory -Clink-args=--export=__heap_base -Clink-args=--export=__wasm_init_tls -Clink-args=--export=__tls_size -Clink-args=--export=__tls_align -Clink-args=--export=__tls_base"` (FRB toolchain: wasm-pack + nightly `-Z build-std`, needs `rust-src` on nightly; dev shell provides `wasm-pack` and `binaryen` so `wasm-opt` resolves locally instead of downloading from GitHub). Run it from the app dir; output lands in gitignored `apps/eve-fit-assistant/web/pkg/` and is copied into `apps/eve-fit-assistant/build/web` by `flutter build web`. The atomics build lets FRB's web worker pool run engine calls (database parsing, emulation) in real Web Workers instead of blocking the browser event loop; FRB routes *normal* fns (not `#[frb(sync)]`, not `async`) through that pool, so the heavy engine APIs in `rust/src/api/server.rs` are deliberately normal fns. lld does not enable shared memory from `+atomics` alone — the `--shared-memory`/`--import-memory`/`--max-memory`/TLS-export link args (wasm-bindgen threading recipe) are required so pool workers can share the same memory instance. The threaded build requires a cross-origin isolated origin: `web/_headers` ships `Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy: require-corp` for Cloudflare Pages, and local dev needs the equivalent headers (e.g. `flutter run -d chrome --web-header=...`); without isolation the app boots without the native engine (`crossOriginIsolated()` probe in `packages/efa_compat/`).
- Web build: `./x build web` (run inside `nix develop .#codegen`; output in `apps/eve-fit-assistant/build/web/`). Wraps the web engine build above plus `flutter build web --wasm --no-web-resources-cdn` (canvaskit/skwasm bundled locally instead of the gstatic CDN, so the bundle is fully self-contained), then prunes canvaskit artifacts unused by the declared renderers (`--no-prune` to skip). The localization SQLite web worker also ships under `web/sqlite/` (`sqlite3.wasm` from simolus3/sqlite3.dart releases matching the `sqlite3` version, `db_worker.js` from powersync-ja/sqlite_async.dart releases matching `sqlite_async`); both are copied into `build/web` and are required for localized names on web.
- Release preflight checks: `./x ci release verify --check-all`.
- Create raw release note: `./x release relnote` (emits `spec.yaml` and `changelog.md`; author `content.zh.md` and `content.en.md` separately).
- Sync canonical version to manifests: `./x release version sync`.
- Bridge crate build/test: `cargo build -p rust_lib_eve_fit_assistant`, `cargo test -p rust_lib_eve_fit_assistant`.
- Engine build/test: `cargo build -p eve-fit-os`, `cargo test -p eve-fit-os`.
- Chat crate test: `cargo test -p efa-chat` (see @docs/agents/efa-chat).
- Single Rust integration test file/function: `cargo test -p eve-fit-os --test test_basic_fit -- --nocapture`; `cargo test -p eve-fit-os test_basic_fit -- --exact --nocapture`.
- Python tests: `./x test python` or `uv run pytest`.
- Flutter/Dart tests: `./x test dart` or `melos run app:test` (or `flutter test` from the app dir).
- Web-platform tests: `./x test web` (headless Chrome via `flutter test --platform chrome`;
  Chrome resolved from `CHROME_EXECUTABLE` or `google-chrome`/`chromium`/`chrome` on PATH).
  Suites are platform-aware: VM-only tests carry `@TestOn("vm")`, web-only tests
  (`test/web/`) carry `@TestOn("browser")`. The web test pipeline compiles every
  suite in the selection regardless of `@TestOn`, so `x.py test web` excludes
  `@TestOn("vm")` suites (their `dart:ffi`-only imports would fail the web compile)
  and instead passes the explicit web-compatible suite list. The pipeline compiles
  to JS, not wasm: the dart2wasm web-test harness cannot run sqlite3_web in headless
  Chrome (dedicated workers and OPFS sync access handles are unavailable there),
  while the JS build exercises the real worker + OPFS path. `x.py test web` also
  mirrors `web/sqlite/{db_worker.js,sqlite3.wasm}` into `test/web/sqlite/` (the web
  test server only serves the `test/` tree), which `localization_db_web_test.dart`
  needs.
- Repo module tests: `dart test test/storage/repo/` (from the app dir).
- Data-flow integration tests (e.g., `test/storage/repo/`) use `package:mocktail`
  for network and filesystem mocks; run with `dart test test/storage/repo/`.
  Async tests require `flutter test` or `dart test` with the Flutter SDK on PATH.
- Regenerate freezed code for models: `melos run app:gen`.
- Migration tests: `dart test test/storage/repo/migration/action/from_v1/` (from the app dir).
- All tests: `./x test all`.

## Data Workspaces And Bundles

- Workspaces are declared in `efa.config.toml`; changing that file is a project-level datasource/config change, not a local preference.
- Select data with `./x workspace list` and `./x workspace default <workspace>`; override per command with `./x --ws <workspace> ...`.
- Build selected workspace data with `./x build data`.
- Generated data depends on external EVE FSD/resource files described by `data/resources/*/descriptor.toml`; missing local resources can block data builds.

## Version

- The canonical version lives in `efa.config.toml` under `[version]`. All other targets (`apps/eve-fit-assistant/pubspec.yaml`, `apps/eve-fit-assistant/rust/Cargo.toml`, `pyproject.toml`) are derived from it. The engine submodule `packages/eve-fit-os` has independent versioning.

## CI / Release Automation

- App releases are driven by GitHub Actions workflows in `.github/workflows/` (see `RELEASING.md` for the manual procedure).
- Release PRs target the `dev` branch and use three labels:
  - `V-Release` — marks the PR as a release and triggers fast preflight checks (`release-preflight.yml`).
  - `V-Test` — triggers the full release test suite (`release-full.yml`), which builds the app and data snapshots in test mode.
  - `V-Tested Release` — added automatically by `release-full.yml` after both app and data tests pass.
- Merging a `V-Release` PR that also has `V-Tested Release` triggers the real release (`release.yml`), which builds all platform artifacts, publishes the joined release to the remote `testing` channel, and creates the Git tag.
- The reusable app release workflow is `_release.yml`; the reusable data snapshot workflow is `_release-data.yml`.
- `_release-data.yml` is organized as: `build` (per-server snapshots + `snapshot-hashes.json`, uploaded as the `v2-snapshots` artifact) → `publish` (session → commit → publish → sync/verify cycle against the remote `testing` channel) → `d1-sync` (registers snapshot engine data into the platform D1 via the data-sync worker; real releases only) → `notify-qqbot` (posts a `data_update` event with one entry per rebuilt server — zh name, game build/version, snapshot creation time from each snapshot's `metadata.json` — to the bofa-qqbot event endpoint using the `QQBOT_EVENT_SECRET` from `production-data`; real releases only).
- `_release.yml` is organized as a symmetric multi-platform pipeline: `verify` (version check, exports `tag`/`version`) → platform build jobs (`android`, `linux`; both `needs: [verify]`, both blocking, sharing the `.github/actions/setup-build-env` composite action parameterized by dev shell; `windows` runs on `windows-latest` with the non-Nix `.github/actions/setup-build-env-windows` composite action) → `publish` (`needs: [verify, android, linux, windows]`; downloads every platform artifact — binaries plus release fragment JSONs — merges all fragments into one release registry via `x build release --fragments ...`, then runs the session → commit → publish → sync/verify cycle against the remote channel) → `tag` (GitHub Release with all platforms' assets) → `notify-qqbot` (posts a `release-created` event with the zh release note to the bofa-qqbot event endpoint using the `QQBOT_EVENT_SECRET` from `production-app`; real releases only). Platform integrity features differ only where the toolchain dictates: APKs are signed and carry Flutter-emitted `.sha1` sidecars; Linux artifacts ship as-is; Windows artifacts (zip + per-user MSI) ship unsigned — installing the MSI shows a SmartScreen warning. Opting in another platform means: extend `release_index.proto` + `make_release_index` + `_RELEASE_PLATFORM_VARIANTS` (publish.py) + `_PLATFORM_DIR` (build.py) + the variant extraction in `bootstrap/cli/remote/session.py`, then add a platform job that uploads its artifacts plus fragment and add its fragment to the `publish` job's merge.
- In test mode both workflows exercise the full commit → publish → sync → verify cycle against a local MinIO mock (`./x remote mock launch --daemon`, stop with `./x remote mock stop`) instead of touching the real remote.
- CI workflows share the tracked developer config `ci/config/efa.dev.toml` (non-secret values; secret fields are `.invalid` placeholders). The composite action `.github/actions/init-dev-env` copies it to `./efa.dev.toml` after checkout; jobs inject real secrets via `--dev-env` overrides on top.
- Publishing credentials live in GitHub Environments, not repository secrets: `production-app` (reviewer-gated; app releases), `production-data` (`dev`-only; data publishes), and `ci-write` (`dev`-only; raw-data uploads). Endpoints/keys are environment secrets, bucket names are variables. PR-triggered builds use a read-only repo-level `CI_STORAGE_*` token. See `RELEASING.md` → "Secrets and environments" for the full map.
- Flutter web delivery pipeline: the `apps/eve-fit-assistant/build/web` bundle (via `x build web`) is deployed to two Cloudflare Pages projects — `efa-app` (production at <https://app.efa-tech.dev>; release-only) and `efa-app-nightly` (nightly preview at <https://app-preview.efa-tech.dev>; branch previews and nightly builds). All jobs build via the shared `.github/actions/build-web` composite action and deploy via `.github/actions/deploy-web-pages`, which copies the tracked `ci/config/wrangler.{prod,nightly}.toml` to `./wrangler.toml` (wrangler requires a config file; same copy-in pattern as `init-dev-env`) and runs `wrangler pages deploy` with `--commit-hash`. Entry points: `web-preview.yml` (PRs to `dev` that touch web bundle inputs — `WEB_PREVIEW_PATTERNS` in `bootstrap/ci/suites.py`, checked via `x.py ci web-affected` — get a branch preview on `efa-app-nightly` plus a pinned PR comment, gated on the `D-CI-Page Preview` label, which `D-Full CI` also enables; release PRs labeled `V-Release` skip this build since `release-full.yml`'s `site`/`site-deploy` jobs build and deploy the web bundle instead; fork PRs get no preview), `site-nightly.yml` (daily cron on `dev`: fetches the last nightly production deployment's commit hash from the Pages API, diffs it against `HEAD`, and only rebuilds/deploys to `efa-app-nightly` when `x.py ci web-affected` says the bundle changed; no PR comment), and `_release.yml` (`site` build job + `site-deploy`: test mode deploys to `efa-app-nightly` with a pinned comment on the release PR; real releases deploy to `efa-app`). Deploy jobs run in GitHub deployment environments — `ci-testing-web` (PR branch previews and release test-mode deploys on `efa-app-nightly`; release test-mode runs from the PR head branch, so it cannot use the dev-restricted `nightly-web`), `nightly-web` (dev-branch-only nightly builds on `efa-app-nightly`), and `production-app` (`efa-app` only) — holding `CLOUDFLARE_API_TOKEN` (Pages:Edit) and `CLOUDFLARE_ACCOUNT_ID`. Each Pages project's production branch must be set to `dev` (one-time dashboard setup).

## Validation Expectations

- After edits, run the relevant formatter and linter; for mixed-language or uncertain changes, run `./x lint`.
- Run relevant tests before committing: `./x test python` or `./x test dart` depending on what changed.
- Dart-only minimum: `melos run app:format` plus `melos run app:analyze`; run `./x generate dart` when annotations/routes/Riverpod/freezed/json models change.
- Python-only minimum: `uv run ruff format` plus `uv run ruff check --fix`.
- Rust bridge minimum: `cargo fmt --package rust_lib_eve_fit_assistant` plus `cargo clippy --fix --allow-dirty --package rust_lib_eve_fit_assistant`.
- Rust fitting-engine logic changes should also run targeted `cargo test -p eve-fit-os ...`.
- Localization changes require `./x generate l10n`; `l10n/app_zh.arb` is the template ARB with placeholder metadata, while `l10n/app_en.arb` should contain translations only.
- JS/TS (site/ dir): run `pnpm run check` in `site/` for SvelteKit type checks; `npx biome check --fix` for formatting/linting.

## Developer Mode

The `AppSetting` model (`lib/storage/setting/setting.dart`) includes a `developerMode` boolean field (default `false`). It is not exposed as a normal settings toggle.

**Access:** On **Settings → Version**, tap the **App Version** value in the version info table 5 times within 2 seconds. A confirmation dialog (`developerModeEnableConfirmTitle` / `developerModeEnableConfirmDescription`) is shown; confirming sets `developerMode` to `true` via `appSettingServiceProvider`. Once enabled, a **Developer Settings** card appears on the Version page.

**Entry points after enabled:**

- Version page → Developer Settings (`/setting/developer-settings`): debug log toggle, remote-content settings visibility, account API endpoint override (production vs. the Cloudflare-Access-protected preview origin, with a `cf-access-token` entry), open remote content settings, collect logs, clear cache, and a shortcut to Developer Tools.
- Developer Settings → Developer Tools (`/setting/developer-tools`): channel overview, restart init, trigger feedback, reset all storage.

**Providers:**

- `developerModeProvider` — reactive read via `ref.watch(developerModeProvider)` (always up-to-date).
- `appSettingServiceProvider.select((s) => s.developerMode)` — fine-grained reactive read.
- `ref.read(appSettingServiceProvider).developerMode` — imperative read within callbacks.

**Localization rule for developer-only widgets:** UI widgets gated behind `developerMode` (i.e., only visible when dev mode is on) **must use hardcoded English**. No ARB entries or `context.l10n` calls for dev-only UI. Only the enable-confirmation dialog and the always-visible Version page elements use localization.

## Style And Generated-Code Gotchas

- Dart analyzer is strict (`strict-casts`, `strict-inference`, `strict-raw-types`) and enforces package imports, double quotes, explicit public API types, and 100-column formatting.
- Python Ruff requires `from __future__ import annotations`, absolute imports, one import per line, double quotes, and 100-column formatting; `apps/eve-fit-assistant/rust/lib/` is excluded from root Ruff.
- Root `rustfmt.toml` uses 100 columns plus field-init and `?` shorthands; the bridge crate stays Rust 2021 because of `flutter_rust_bridge`.
- Keep FRB-facing APIs small and explicit in `apps/eve-fit-assistant/rust/src/api/`; put core fitting behavior in `packages/eve-fit-os` when possible. Choose the FRB fn flavor by threading intent: `#[frb(sync)]` runs on the caller's thread/event loop (cheap calls only), `async` runs on the main browser event loop on web (never for CPU-heavy work), and a plain ("normal") fn runs on FRB's thread pool — backed by the Web Worker pool on web, which the atomics build plus COOP/COEP headers (see the web engine build note) enable. Heavy engine work must stay in normal fns.
- Do not manually edit generated bridge/localization/protobuf/build outputs unless the task is explicitly about generated artifacts; change sources and run the matching generator.

## Python Pipeline

- `bootstrap/remote/session_model.py` — Session manager for the `efa/v2/` layout
  (`SessionManager`), inheriting from `_BaseSessionManager`. Manages
  generation lifecycle, resource registration, release
  management, and S3/R2 publishing.

## Local Instruction Sources

- `flake.nix` and `.github/workflows/` are the sources of truth for CI/CD; release procedures are documented in `RELEASING.md`.
- No `.cursor/rules/`, `.cursorrules`, or `opencode.json`.
- `CLAUDE.md` is a symlink to this file.
