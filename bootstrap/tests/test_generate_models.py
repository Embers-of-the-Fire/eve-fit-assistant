"""Tests for the models generator step helpers (bootstrap.data.workspace.generate.models)."""

from __future__ import annotations

import pytest

from bootstrap.data.workspace.generate.models import chunk_convert_jobs


def _jobs(n: int) -> list[dict]:
    return [{"id": str(i), "dna": f"hull:faction:race{i}"} for i in range(n)]


class TestChunkConvertJobs:
    def test_empty(self):
        assert chunk_convert_jobs([], 4, None) == []

    def test_derived_batch_size_is_four_times_finer_than_workers(self):
        # 64 jobs on 4 workers -> shard size 4 -> 16 shards.
        shards = chunk_convert_jobs(_jobs(64), 4, None)
        assert [len(shard) for shard in shards] == [4] * 16

    def test_derived_batch_size_minimum_one(self):
        shards = chunk_convert_jobs(_jobs(3), 8, None)
        assert [len(shard) for shard in shards] == [1, 1, 1]

    def test_explicit_batch_size(self):
        shards = chunk_convert_jobs(_jobs(7), 4, 3)
        assert [len(shard) for shard in shards] == [3, 3, 1]

    def test_single_shard_when_batch_covers_all(self):
        assert len(chunk_convert_jobs(_jobs(5), 4, 10)) == 1

    def test_order_and_content_preserved(self):
        jobs = _jobs(10)
        shards = chunk_convert_jobs(jobs, 2, None)
        assert [job for shard in shards for job in shard] == jobs

    @pytest.mark.parametrize("batch_size", [None, 1, 7])
    def test_no_job_is_duplicated_or_dropped(self, batch_size: int | None):
        jobs = _jobs(23)
        shards = chunk_convert_jobs(jobs, 3, batch_size)
        flattened = [job["id"] for shard in shards for job in shard]
        assert sorted(flattened, key=int) == [job["id"] for job in jobs]


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__]))
