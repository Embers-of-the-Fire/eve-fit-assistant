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
`static`, `native`, `localization`, `agent`, `images`, `models`, `skyboxes` (skippable via
`--skip <name>`). The `models` step bakes per-ship GLB models with the
`tools/carbon-gr2-to-glb` submodule (Node.js), converting shards across parallel
converter processes (`--models-threads`, default: CPU count; `--models-batch-size`
jobs per shard, default derived from the thread count): it resolves ship DNAs from the FSD tables,
stages `data.black`/GR2/DDS assets through the workspace `ResourceManager` (the converter
never touches the network), and emits meshopt-compressed GLBs under
`static/models/ships/<typeID>.<variant>.glb` — two variants per ship: `full` (baked WebP
PBR textures; WebP rides as plain `image/webp` sources without EXT_texture_webp, an
app-internal contract for the Flutter Scene viewer, which decodes WebP by content) and
`base` (geometry-only, factor-only materials, no textures). Model resources are NON_FORCE
(lazy) via the `static/models/` rule in `data/schema/resource_resolution.toml` (RRS v3);
snapshots carrying them stamp resource index `format_version` 4, which older clients
reject through the app-update gate (they would otherwise classify the unknown prefixes as
eager).

The `skyboxes` step bakes every `res:/dx9/scene/{universe,wormholes,abyssal,fitting}/`
skybox cubemap (`*_cube.dds`, BC6H_SF16 2048² — except y01, the one LDR outlier, which the
converter decodes from BC7; the fitting cubes are 1024², and the legacy
`wormhole_class_00.dds` carries no `_cube` suffix) into a 2048×1024 Radiance `.hdr` equirect plus
a `SkyboxMetadata` protobuf sidecar (`data/schema/skybox.proto`: the `.black` descriptor's
`nebulaIntensity`/`reflectionIntensity`/`ambientColor`/`Tint`, unset when absent, plus the
precomputed diffuse SH in flutter_scene's convention) under `static/skyboxes/<id>.hdr`/`.pb2`, via the same
converter's `--batch-skybox` verb. Skybox resources are NON_FORCE (lazy) via the
`static/skyboxes/` RRS rule. The `types` step also stamps `Type.race_id`/`faction_id`
and `Collection.faction_races` (the FSD `memberRaces` faction→race mapping), which the
app uses to pick each ship's default skybox.

### Models build-state cache

Model conversion dominates data-build time (~2 s per ship per variant), so the `models`
step memoizes per-artifact results. A per-server JSON map in CI storage
(`build-state/models/<server>.json`) records each output resource id's input identity
(GR2 MD5 plus texture MD5s from the `resfileindex.txt` hash column, the SOF DNA, and a
per-DNA SOF fingerprint: the converter resolve phase's sha256 over the resolved SOF
values — geometry path, per-area shaders, texture paths, material constants, and glow
colors) and output blob hash;
output blobs live only in the production store, referenced in place. A cache entry is
reused only when (1) all input hashes match, (2) the texture key set is unchanged,
(3) the DNA and SOF fingerprint match (the fingerprint covers exactly the values the
converter derives from `data.black`, so catalog changes that leave a DNA's resolved
values untouched — e.g. a new unrelated hull — do not invalidate it), and
(4) the recorded output blob still exists in the production store; hits are referenced
in place (the snapshot index points at the production blob — the HEAD that checks rule 4
also captures the blob's size, and nothing is downloaded) instead of re-converted. Everything fails open: a missing,
corrupt, or schema-mismatched map — or any un-hashable input — means "reconvert."

The map carries no converter identity: when the converter submodule or the encoder
toolchain changes, invalidate manually (see RELEASING.md). Test-mode/PR builds never
read or write the map (they publish to a mock, so their outputs do not exist in the
production store). Operators manage the map with `./x ci build-state ...`
(`invalidate`, `seed`, `push-models`, `commit`).

The `skyboxes` step has its own per-server map (`build-state/skyboxes/<server>.json`)
with the same invalidation model: each entry keys on the resindex MD5 columns of the
cube DDS and its `.black` descriptor, and records both output blob hashes (`.hdr` and
`.pb2`); a hit requires unchanged inputs and both production blobs present. It is
enabled and rewritten by the same release-data flags as the models map
(`--models-cache` / `--rebuild-models`); it has no dedicated `./x ci build-state`
subcommands.

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
`content.en.md` separately. The `changelog` assistant skill encodes the curated bilingual
release-note workflow.
