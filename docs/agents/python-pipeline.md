# Python Pipeline

Python code in `bootstrap/`, together with `x.py`, owns workspace management, code-generation
orchestration, CI/release helpers, and static data packaging.

## Remote Session Model

`bootstrap/remote/__init__.py` contains `SessionManager`, the top-level facade for the EFA V2
schema dev-side pipeline. It manages:

- channel registry and channel-head lifecycle;
- blob and resource/release snapshot storage;
- generation creation and loading;
- publishing, synchronization, verification, and garbage collection against S3/R2-backed
  remote storage.

## Local Rules

- Run the workspace CLI through `./x`, `./x.ps1`, or `uv run x.py`; do not use a global
  Python interpreter.
- Python changes should use the repository's Ruff configuration: `from __future__ import
  annotations`, absolute imports, one import per line, double quotes, and 100-column
  formatting.
- Python tests run with `./x test python` or `uv run pytest`.
