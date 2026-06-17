"""Generation store — immutable generation CRUD and parent-chain walking.

Generations are stored at channels/refs/{generation_hash}/ with five files:
  metadata.json, server.pb2, resources.pb2, releases.pb2, announcements.pb2
"""

from __future__ import annotations

import datetime
import shutil

from dataclasses import dataclass
from typing import TYPE_CHECKING

from data.lib.remote.hash import generation_hash as _compute_generation_hash
from data.lib.remote.models import GenerationMetadata
from data.lib.remote.models import read_json
from data.lib.remote.models import read_pb2
from data.lib.remote.models import write_json
from data.lib.remote.models import write_pb2
from data.lib.remote.paths import generation_dir
from data.lib.remote.paths import temp_generation_dir


if TYPE_CHECKING:
    from collections.abc import Iterator
    from pathlib import Path

    from data.lib.remote.models import GenerationPointer
    from data.lib.remote.models import GenerationResources
    from data.lib.remote.models import ServerIndex


@dataclass
class Generation:
    hash: str
    metadata: GenerationMetadata
    server_index: ServerIndex
    resources: GenerationResources
    release_pointer: GenerationPointer
    announcement_pointer: GenerationPointer


class GenerationStore:
    """Read/write generations under channels/refs/{generation_hash}/."""

    def __init__(self, root: Path) -> None:
        self.root = root

    def create(
        self,
        metadata: GenerationMetadata,
        server_index_msg: ServerIndex,
        resources_msg: GenerationResources,
        release_pointer: GenerationPointer,
        announcement_pointer: GenerationPointer,
    ) -> str:
        """Create a generation atomically, returning its hash.

        Writes all five files to a temp directory, computes the structured
        generation hash, then renames to the final location.
        """
        temp_dir = temp_generation_dir(self.root)
        if temp_dir.exists():
            shutil.rmtree(temp_dir, ignore_errors=True)
        temp_dir.mkdir(parents=True, exist_ok=True)

        write_json(temp_dir / "metadata.json", metadata)
        write_pb2(temp_dir / "server.pb2", server_index_msg)
        write_pb2(temp_dir / "resources.pb2", resources_msg)
        write_pb2(temp_dir / "releases.pb2", release_pointer)
        write_pb2(temp_dir / "announcements.pb2", announcement_pointer)

        files = {
            "metadata.json": (temp_dir / "metadata.json").read_bytes(),
        }

        gen_hash = _compute_generation_hash(files)
        target_dir = generation_dir(self.root, gen_hash)

        if not target_dir.exists():
            temp_dir.rename(target_dir)
        else:
            shutil.rmtree(temp_dir, ignore_errors=True)

        return gen_hash

    def load(self, gen_hash: str) -> Generation:
        gen_dir = generation_dir(self.root, gen_hash)
        if not gen_dir.is_dir():
            raise FileNotFoundError(f"Generation not found: {gen_dir}")

        from data.lib.remote.models import GenerationPointer
        from data.lib.remote.models import GenerationResources
        from data.lib.remote.models import ServerIndex

        meta = GenerationMetadata.model_validate(read_json(gen_dir / "metadata.json"))
        return Generation(
            hash=gen_hash,
            metadata=meta,
            server_index=read_pb2(gen_dir / "server.pb2", ServerIndex),
            resources=read_pb2(gen_dir / "resources.pb2", GenerationResources),
            release_pointer=read_pb2(gen_dir / "releases.pb2", GenerationPointer),
            announcement_pointer=read_pb2(gen_dir / "announcements.pb2", GenerationPointer),
        )

    def walk_parent_chain(self, start_hash: str) -> Iterator[Generation]:
        """Walk from start_hash up through parent references to the root.

        Yields generations in tip→root order (latest first).
        """
        visited: set[str] = set()
        current = start_hash
        while current and current not in visited:
            gen = self.load(current)
            yield gen
            visited.add(current)
            current = gen.metadata.parent or ""

    def list_all(self) -> dict[str, Generation]:
        refs_dir = self.root / "channels" / "refs"
        if not refs_dir.is_dir():
            return {}
        result: dict[str, Generation] = {}
        for entry in sorted(refs_dir.iterdir()):
            if not entry.is_dir():
                continue
            if entry.name.startswith("tmp"):
                continue
            if not (entry / "metadata.json").is_file():
                continue
            result[entry.name] = self.load(entry.name)
        return result

    def delete(self, gen_hash: str) -> None:
        gen_dir = generation_dir(self.root, gen_hash)
        if gen_dir.exists():
            shutil.rmtree(gen_dir, ignore_errors=True)


def utc_timestamp() -> str:
    return (
        datetime.datetime.now(datetime.UTC)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )
