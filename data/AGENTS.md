# Data Sources And Schemas

Scope: raw EVE resources in `resources/` and protobuf schema sources in `schema/`.

- This directory is source data, not generated output. Generated Dart, Python, and TypeScript
  bindings live in their respective package/bootstrap locations and are gitignored.
- External EVE FSD/resource inputs are described by `resources/*/descriptor.toml`; missing
  resources can block data builds.
- Data workspaces are declared in the root `efa.config.toml`; changing that file is a
  project-level datasource/configuration change.
- Schema changes require `./x generate protobuf` and updates to affected consumers.
- `schema/resource_resolution.toml` is the Resource Resolution Schema (RRS) spec: the
  download rules, RRS version, evaluation context, and layout vocabulary. It drives
  `./x generate dart` (the app's `resolveResource` evaluator) and the pipeline's stamped
  `download_policy`; rule literals must stay in sync with its `[vocabulary]` (pinned by
  `bootstrap/tests/test_resolution_spec.py`). Its fixed Dart header lives in
  `schema/resource_resolution.header.dart`.

Common commands:

```sh
./x workspace list
./x workspace default <workspace>
./x --ws <workspace> build data
./x generate protobuf
```

See @docs/agents/data-versioning and @docs/agents/environment for the full workflow.
