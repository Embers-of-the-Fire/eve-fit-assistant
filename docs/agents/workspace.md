# Workspace Shape

This document maps the repository's major areas. Scoped operating rules live in the nearest
`AGENTS.md`; deeper subsystem behavior lives in the other documents indexed by
@docs/agents/README.

## Control Plane

| Path | Role |
| ---- | ---- |
| `efa.config.toml` | Canonical version, declared data workspaces, and project-level datasource configuration. |
| `pubspec.yaml` / `melos.yaml` configuration in the root pub workspace | Melos workspace for Dart/Flutter packages; app-scoped tasks use `app:*` scripts. |
| `Cargo.toml` | Cargo workspace root. |
| `pyproject.toml` / `uv.lock` | Python 3.13+ project and locked `uv` environment. |
| `flake.nix` | Primary Linux development environment and toolchain source of truth. |
| `./x`, `./x.ps1`, `x.py` | Workspace CLI and its Python implementation. Prefer `./x --help` over copied command prose. |

## Flutter App

The application lives in `apps/eve-fit-assistant/` and is managed through the root melos pub
workspace. Flutter-scoped tests, analysis, formatting, code generation, localization, and
platform builds are exposed as melos `app:*` scripts, with `./x` delegating to them where an
`x` command exists.

Generated Dart outputs include app-relative `lib/native/`, `lib/data/l10n/`, `*.g.dart`, and
`*.freezed.dart`. Do not edit those outputs by hand; update their sources and rerun the
matching generator.

`apps/eve-fit-assistant/rust_builder/` is the Flutter plugin/cargokit wrapper referenced by
the app's `pubspec.yaml`; it is not the main Rust source tree.

## Dart Packages

| Path | Role |
| ---- | ---- |
| `packages/acl/` | ACL token DSL library (`{domain}:{action}[:{qualifier}]`): Dart runtime in `dart/`, TypeScript runtime in `ts/`, and the YAML-driven codegen CLI in `tool/`; fixtures regenerate via `./x generate acl` or `melos run acl:gen`. |
| `packages/efa_proto/` | Dart protobuf bindings generated from `data/schema/` by `./x generate protobuf`; imported as `package:efa_proto/<name>.pb.dart`. Generated files are gitignored. |
| `packages/efa_constant/` | Dependency-free EVE constants exposed as `package:efa_constant/eve.dart`; `eve_dogma_unit_generated.dart` is tracked and `eve_attr_generated.dart` is generated/gitignored. |
| `packages/efa_fit/` | Pure-Dart fit formats: EFA(n) payload codecs, EFT import/export, and fit-link URI construction/parsing. |
| `packages/efa_platform_client/` | Pure-Dart platform API facade: `PlatformSession` owns the account auth flows, the token lifecycle, and the public platform reads. |
| `packages/efa_compat/` | Shared compatibility helpers, including the web cross-origin-isolation probe. |
| `packages/efa_component/` | Shared Dart components. |
| `packages/efa_fit_snapshot/` | Fit snapshot Dart support. |
| `packages/efa_fit_snapshot_ts/` | TypeScript fit snapshot support. |
| `packages/efa_platform_client_ts/` | TypeScript platform account client: `PlatformSession` (auth flows, token lifecycle) for browser consumers such as `site/platform`. |
| `packages/efa_proto_ts/` | protobuf-es TypeScript bindings for platform-facing fit schemas; generated into gitignored `src/gen/` by `buf`. |
| `packages/eve-fit-os/` | Fitting-engine Git submodule with independent versioning. Initialize with `git submodule update --init` after cloning. |

## Rust Crates

Rust has three main crates:

- the Flutter Rust Bridge crate in `apps/eve-fit-assistant/rust/` (`rust/src/api/*`);
- the fitting engine submodule in `packages/eve-fit-os/`;
- the AI chat crate in `apps/eve-fit-assistant/rust/lib/efa-chat/` (see @docs/agents/efa-chat).

The root `Cargo.toml` is the Cargo workspace root. Keep FRB-facing APIs in the bridge crate
small and put core fitting behavior in `packages/eve-fit-os` where practical.

## Python And Data

Python code in `bootstrap/`, plus `x.py`, owns workspace management, code-generation
orchestration, CI/release helpers, and static data packaging. The top-level `data/` tree is
limited to raw EVE resources (`data/resources/`) and protobuf schema sources
(`data/schema/`). Generated Python protobuf bindings live in `bootstrap/data/schema/` as
top-level `<name>_pb2` modules on `sys.path` and are gitignored.

## Web And Edge

The homepage and platform app are members of the root pnpm workspace; the manual site has its
own pnpm workspace. Root `biome.json` governs JS/TS formatting and linting for the site area.
The Cloudflare Workers used by the release and platform infrastructure live in `worker/`.
Native packaging assets live in `distro/linux/` and `distro/windows/`.

## Path Convention

In repository documentation, app paths written as `lib/...`, `test/...`, `rust/...`,
`l10n/...`, or `web/...` are relative to `apps/eve-fit-assistant/` unless stated otherwise.
