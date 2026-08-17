from __future__ import annotations

import sys

from pathlib import Path


# Generated protobuf modules use flat sibling imports (e.g. `import fit_pb2`)
# because protoc ignores package structure for Python. Register this directory
# so package-style imports like `bootstrap.data.schema.fit_snapshot_pb2` work.
_schema_dir = str(Path(__file__).resolve().parent)
if _schema_dir not in sys.path:
    sys.path.append(_schema_dir)
