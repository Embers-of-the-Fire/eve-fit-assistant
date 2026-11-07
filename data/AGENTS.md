# Data Sources And Schemas

Scope: raw EVE resources in `resources/` and protobuf schema sources in `schema/`.

- This directory is source data, not generated output; generated bindings live in their
  package/bootstrap locations and are gitignored. Never edit generated outputs by hand.
- External EVE FSD/resource inputs are described by `resources/*/descriptor.toml`; missing
  resources can block data builds.
- Data workspaces are declared in the root `efa.config.toml`; changing that file is a
  project-level datasource/configuration change.
- Schema changes require `./x generate protobuf` and updates to affected consumers.
- `schema/resource_resolution.toml` is the Resource Resolution Schema (RRS) spec: the
  download rules, RRS version, evaluation context, and layout vocabulary. It drives
  `./x generate dart` (the app's `resolveResource` evaluator) and the pipeline's stamped
  `download_policy`; changing it without running `./x generate dart` leaves the local app
  with stale download rules. Rule literals must stay in sync with its `[vocabulary]`
  (pinned by `bootstrap/tests/test_resolution_spec.py`). Its fixed Dart header lives in
  `schema/resource_resolution.header.dart`.

## Docs

- Data workspaces and canonical versioning: [docs/dev/data-versioning.md](../docs/dev/data-versioning.md)
- Environment setup: [docs/dev/setup-and-config.md](../docs/dev/setup-and-config.md)
