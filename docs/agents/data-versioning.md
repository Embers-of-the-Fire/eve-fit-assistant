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
./x release relnote
```

The command emits `spec.yaml` and `changelog.md`; author `content.zh.md` and
`content.en.md` separately. The `changelog` OpenCode skill contains the curated bilingual
release-note workflow.
