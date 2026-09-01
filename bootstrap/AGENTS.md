# Bootstrap Python Tooling

Scope: Python workspace tooling in `bootstrap/`, including the implementation behind `x.py`.

## Local Rules

- Run the CLI as `./x`, `./x.ps1`, or `uv run x.py` from the repository root; do not rely on
  a global Python interpreter.
- Python requires 3.13+ and dependencies are managed by `uv`.
- Follow the repository Ruff rules: future annotations, absolute imports, one import per
  line, double quotes, and 100-column formatting.
- Generated protobuf modules under `bootstrap/data/schema/` are outputs; change
  `data/schema/` and regenerate instead of editing them.
- CI/release behavior must stay aligned with `.github/workflows/` and `RELEASING.md`.
- Change-aware CI/CD selection is the four-layer system in `bootstrap/ci/`: package registry
  (`registry.py`), codegen step graph (`codegen.py`), task catalog (`catalog.py`), resolver
  (`resolve.py`); keep the registry in sync with the real manifests —
  `bootstrap/tests/test_ci_registry.py` enforces this.

## Detail Docs

- Python pipeline and remote session model: @docs/agents/python-pipeline
- Environment setup: @docs/agents/environment
- Data workspaces and versioning: @docs/agents/data-versioning
- CI/release workflows: @docs/agents/ci-release

## Validation

```sh
uv run ruff format
uv run ruff check --fix
./x test python
```
