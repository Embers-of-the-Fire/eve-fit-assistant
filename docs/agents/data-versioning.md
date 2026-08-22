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
