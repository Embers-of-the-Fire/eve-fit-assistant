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
(lazy) via the `[resolution]` vocabulary's `static_models_prefix`; snapshots carrying them
stamp resource index `format_version` 3, which format-2 clients reject through the
app-update gate (RRS v1 would otherwise classify the unknown prefix as eager).

## Canonical Version

The canonical application version lives in `efa.config.toml` under `[version]`. Derived
manifests include:

- `apps/eve-fit-assistant/pubspec.yaml`;
- `apps/eve-fit-assistant/rust/Cargo.toml`;
- `pyproject.toml`.

Sync derived manifests with:

```sh
./x release version sync
```

The fitting-engine submodule `packages/eve-fit-os` has independent versioning.

## Release Notes

Create the raw release-note scaffold with:

```sh
./x release relnote
```

The command emits `spec.yaml` and `changelog.md`; author `content.zh.md` and
`content.en.md` separately. The `changelog` OpenCode skill contains the curated bilingual
release-note workflow.
