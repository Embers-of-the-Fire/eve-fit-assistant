# Data Workspaces And Versioning

## Data Workspaces

Data workspaces are declared in `efa.config.toml`; changing that file is a project-level
datasource/configuration change, not a local preference.

Common commands:

```sh
./x workspace list
./x workspace default <workspace>
./x --ws <workspace> <command>
./x build data
```

Generated data depends on external EVE FSD/resource files described by
`data/resources/*/descriptor.toml`; missing local resources can block data builds.

## Generator Steps

`./x build data` runs the generators in `bootstrap/data/workspace/generate/` in order:
`static`, `native`, `localization`, `agent`, `images`, `models` (skippable via
`--skip <name>`). The `models` step bakes per-ship GLB models with the
`tools/carbon-gr2-to-glb` submodule (Node.js): it resolves ship DNAs from the FSD tables,
stages `data.black`/GR2/DDS assets through the workspace `ResourceManager` (the converter
never touches the network), and emits meshopt-compressed GLBs under
`static/models/ships/<typeID>.<variant>.glb` — two variants per ship: `full` (baked WebP
PBR textures; WebP rides as plain `image/webp` sources without EXT_texture_webp, an
app-internal contract for the Flutter Scene viewer, which decodes WebP by content) and
`base` (geometry-only, factor-only materials, no textures). Model resources are NON_FORCE
(lazy) via the `static/models/` rule in `data/schema/resource_resolution.toml` (RRS v2);
snapshots carrying them stamp resource index `format_version` 3, which format-2 clients
reject through the app-update gate (RRS v1 would otherwise classify the unknown prefix as
eager).

### Models build-state cache

Model conversion dominates data-build time (~2 s per ship per variant), so the `models`
step memoizes per-artifact results. A per-server JSON map in CI storage
(`build-state/models/<server>.json`) records each output resource id's input hashes
(GR2 MD5 plus texture MD5s from the `resfileindex.txt` hash column) and output blob hash;
output blobs live only in the production store, referenced in place. A cache entry is
reused only when (1) all input hashes match, (2) the texture key set is unchanged, and
(3) the recorded output blob still exists in the production store; hits are rehydrated
(downloaded) from production instead of re-converted. Everything fails open: a missing,
corrupt, or schema-mismatched map — or any un-hashable input — means "reconvert."

The map carries no converter identity: when the converter submodule or the encoder
toolchain changes, invalidate manually (see RELEASING.md). Test-mode/PR builds never
read or write the map (they publish to a mock, so their outputs do not exist in the
production store). Operators manage the map with `./x ci build-state ...`
(`invalidate`, `seed`, `push-models`, `commit`).

## Canonical Version

The canonical application version lives in `efa.config.toml`: shared fields under
`[version]` (`build`, `data_schema`) plus the per-track groups `[version.testing]`
(`major.minor.patch-beta.num+build`) and `[version.stable]` (`major.minor.patch+build`).
Derived manifests include:

- `apps/eve-fit-assistant/pubspec.yaml`;
- `apps/eve-fit-assistant/rust/Cargo.toml`;
- `pyproject.toml`.

Sync derived manifests with (default track `testing`; committed manifests carry the
testing rendering):

```sh
./x release version sync --track testing
```

The fitting-engine submodule `packages/eve-fit-os` has independent versioning. See
`RELEASING.md` for the full dual-track version model and release flow.

## Release Notes

Create the raw release-note scaffold with:

```sh
./x release relnote --track testing --from-ref releases/v<previous-tag>
```

The command emits `spec.yaml` and `changelog.md`; author `content.zh.md` and
`content.en.md` separately. The `changelog` OpenCode skill contains the curated bilingual
release-note workflow.
