# Bootstrap Python Tooling

Scope: Python workspace tooling in `bootstrap/`, including the implementation behind `x.py`.

## Hard Constraints

- Run the CLI as `./x`, `./x.ps1`, or `uv run x.py` from the repository root; do not rely on
  a global Python interpreter.
- Generated protobuf modules under `bootstrap/data/schema/` are outputs; change
  `data/schema/` and regenerate instead of editing them.
- CI/release behavior must stay aligned with `.github/workflows/` and `RELEASING.md`.
- Change-aware CI/CD selection is the four-layer system in `bootstrap/ci/` (registry,
  codegen, catalog, resolver); keep the registry in sync with the real manifests —
  `bootstrap/tests/test_ci_registry.py` enforces this.

## Docs

- Python pipeline and remote session model: [docs/dev/python-pipeline.md](../docs/dev/python-pipeline.md)
- Environment setup: [docs/dev/setup-and-config.md](../docs/dev/setup-and-config.md)
- Data workspaces and versioning: [docs/dev/data-versioning.md](../docs/dev/data-versioning.md)
- CI/release workflows: [docs/dev/ci-release.md](../docs/dev/ci-release.md)
- Validation: `uv run ruff format && uv run ruff check --fix && ./x test python`
