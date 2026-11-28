"""Tests for the models generator step helpers (bootstrap.data.workspace.generate.models)."""

from __future__ import annotations

import json

from pathlib import Path

import pytest

from bootstrap.data.workspace.generate.models import ConversionFailure
from bootstrap.data.workspace.generate.models import IncompleteConversionError
from bootstrap.data.workspace.generate.models import ShardReport
from bootstrap.data.workspace.generate.models import build_conversion_diagnostics
from bootstrap.data.workspace.generate.models import cache_eligible
from bootstrap.data.workspace.generate.models import chunk_convert_jobs
from bootstrap.data.workspace.generate.models import classify_resolve_error
from bootstrap.data.workspace.generate.models import conversion_failure_reason
from bootstrap.data.workspace.generate.models import evaluate_conversion_jobs
from bootstrap.data.workspace.generate.models import fully_staged_textures
from bootstrap.data.workspace.generate.models import merge_variant_results
from bootstrap.data.workspace.generate.models import parse_stats_report
from bootstrap.data.workspace.generate.models import remove_stale_ship_model_outputs
from bootstrap.data.workspace.generate.models import shard_report_entry
from bootstrap.data.workspace.generate.models import staged_requirement_missing
from bootstrap.data.workspace.generate.paths import ShipModelVariant


JOB = {
    "id": "587",
    "dna": "mf4_t1:minmatarbase:minmatar",
    "geometryResPath": "res:/dx9/model/mf4_t1.gr2",
    "textureResPaths": ["res:/dx9/model/mf4_t1_a.dds", "res:/dx9/model/mf4_t1_n.dds"],
}


def staged_map(job: dict, *missing: str) -> dict[str, Path | None]:
    staged: dict[str, Path | None] = {job["geometryResPath"]: Path("/staged/mf4_t1.gr2")}
    staged.update(
        {
            res_path: Path(f"/staged/{index}.dds")
            for index, res_path in enumerate(job["textureResPaths"])
        }
    )
    for res_path in missing:
        staged[res_path] = None
    return staged


def shard_report(
    results: list[dict],
    index: int = 1,
    returncode: int = 0,
    stderr_tail: str = "",
    parse_error: str | None = None,
) -> ShardReport:
    return ShardReport(
        variant=ShipModelVariant.FULL,
        index=index,
        manifest_name=f"manifest_convert_full_main_{index}.json",
        stats_name=f"stats_convert_full_main_{index}.json",
        returncode=returncode,
        stderr_tail=stderr_tail,
        results=tuple(results),
        parse_error=parse_error,
    )


def _jobs() -> list[dict]:
    return [
        {"id": "587", "dna": "dna-a"},
        {"id": "588", "dna": "dna-b"},
    ]


def _verified_result(
    result_id: str, dna: str, variant: ShipModelVariant = ShipModelVariant.FULL
) -> dict:
    return {
        "id": result_id,
        "stats": {"complete": True, "variant": variant.value, "dna": dna},
    }


class TestChunkConvertJobs:
    def test_empty(self):
        assert chunk_convert_jobs([], 4, None) == []

    def test_derived_batch_size_is_four_times_finer_than_workers(self):
        # 64 jobs on 4 workers -> shard size 4 -> 16 shards.
        shards = chunk_convert_jobs(_chunk_jobs(64), 4, None)
        assert [len(shard) for shard in shards] == [4] * 16

    def test_derived_batch_size_minimum_one(self):
        shards = chunk_convert_jobs(_chunk_jobs(3), 8, None)
        assert [len(shard) for shard in shards] == [1, 1, 1]

    def test_explicit_batch_size(self):
        shards = chunk_convert_jobs(_chunk_jobs(7), 4, 3)
        assert [len(shard) for shard in shards] == [3, 3, 1]

    def test_single_shard_when_batch_covers_all(self):
        assert len(chunk_convert_jobs(_chunk_jobs(5), 4, 10)) == 1

    def test_order_and_content_preserved(self):
        jobs = _chunk_jobs(10)
        shards = chunk_convert_jobs(jobs, 2, None)
        assert [job for shard in shards for job in shard] == jobs

    @pytest.mark.parametrize("batch_size", [None, 1, 7])
    def test_no_job_is_duplicated_or_dropped(self, batch_size: int | None):
        jobs = _chunk_jobs(23)
        shards = chunk_convert_jobs(jobs, 3, batch_size)
        flattened = [job["id"] for shard in shards for job in shard]
        assert sorted(flattened, key=int) == [job["id"] for job in jobs]


def _chunk_jobs(n: int) -> list[dict]:
    return [{"id": str(i), "dna": f"hull:faction:race{i}"} for i in range(n)]


class TestStagedRequirementMissing:
    def test_all_staged_full(self):
        assert staged_requirement_missing(JOB, staged_map(JOB), ShipModelVariant.FULL) is None

    def test_all_staged_base(self):
        assert staged_requirement_missing(JOB, staged_map(JOB), ShipModelVariant.BASE) is None

    def test_missing_geometry(self):
        staged = {**staged_map(JOB), JOB["geometryResPath"]: None}
        reason = staged_requirement_missing(JOB, staged, ShipModelVariant.FULL)
        assert reason == "geometry-missing"

    def test_absent_geometry_path(self):
        job = {key: value for key, value in JOB.items() if key != "geometryResPath"}
        assert staged_requirement_missing(job, {}, ShipModelVariant.BASE) == "geometry-missing"

    def test_missing_texture_fails_full(self):
        missing = JOB["textureResPaths"][1]
        reason = staged_requirement_missing(JOB, staged_map(JOB, missing), ShipModelVariant.FULL)
        assert reason == f"texture-missing:{missing}"

    def test_missing_texture_ignored_for_base(self):
        missing = JOB["textureResPaths"][1]
        reason = staged_requirement_missing(JOB, staged_map(JOB, missing), ShipModelVariant.BASE)
        assert reason is None


class TestFullyStagedTextures:
    def test_all_staged(self):
        assert fully_staged_textures(JOB, staged_map(JOB)) is True

    def test_one_missing(self):
        staged = staged_map(JOB, JOB["textureResPaths"][0])
        assert fully_staged_textures(JOB, staged) is False

    def test_no_textures_required(self):
        job = {**JOB, "textureResPaths": []}
        assert fully_staged_textures(job, {}) is True


class TestParseStatsReport:
    def test_valid_report(self):
        document = {"results": [{"id": "587", "stats": {"complete": True}}]}
        results, parse_error = parse_stats_report(json.dumps(document))
        assert parse_error is None
        assert results == [{"id": "587", "stats": {"complete": True}}]

    def test_invalid_json(self):
        results, parse_error = parse_stats_report("not json")
        assert results == []
        assert parse_error is not None

    def test_missing_results_list(self):
        results, parse_error = parse_stats_report("{}")
        assert results == []
        assert parse_error is not None

    def test_non_dict_results_filtered(self):
        document = {"results": ["garbage", {"id": "1"}]}
        results, parse_error = parse_stats_report(json.dumps(document))
        assert parse_error is None
        assert results == [{"id": "1"}]


class TestConversionFailureReason:
    def test_missing_result(self):
        assert conversion_failure_reason(None) == "no-batch-result"

    def test_error_result(self):
        reason = conversion_failure_reason({"id": "587", "error": "decode failed"})
        assert reason is not None
        assert reason.startswith("converter-error:")

    def test_incomplete_flag(self):
        reason = conversion_failure_reason({"id": "587", "incomplete": True})
        assert reason == "incomplete"

    def test_stats_absent(self):
        assert conversion_failure_reason({"id": "587"}) == "incomplete"

    @pytest.mark.parametrize("stats", [{}, {"complete": False}, None])
    def test_incomplete_stats(self, stats):
        assert conversion_failure_reason({"id": "587", "stats": stats}) == "incomplete"

    def test_verified_result(self):
        result = {"id": "587", "stats": {"complete": True}}
        assert conversion_failure_reason(result) is None


class TestEvaluateConversionJobs:
    def test_all_verified_produced(self):
        results_by_id = {
            "587": _verified_result("587", "dna-a"),
            "588": _verified_result("588", "dna-b"),
        }
        produced, failures = evaluate_conversion_jobs(_jobs(), results_by_id, ShipModelVariant.FULL)
        assert produced == {"dna-a", "dna-b"}
        assert failures == []

    def test_variant_or_dna_mismatch_is_not_verified(self):
        results_by_id = {
            "587": _verified_result("587", "dna-a", ShipModelVariant.BASE),
            "588": _verified_result("588", "some-other-dna"),
        }
        produced, failures = evaluate_conversion_jobs(_jobs(), results_by_id, ShipModelVariant.FULL)
        assert produced == set()
        assert [failure.reason for failure in failures] == [
            "variant-mismatch:base",
            "dna-mismatch",
        ]

    def test_missing_batch_result_is_failure_not_file_existence(self):
        # Success requires a batch result; the helper never consults output
        # paths, so a leftover GLB on disk can never count as a success.
        results_by_id = {"587": _verified_result("587", "dna-a")}
        produced, failures = evaluate_conversion_jobs(_jobs(), results_by_id, ShipModelVariant.FULL)
        assert produced == {"dna-a"}
        assert len(failures) == 1
        assert failures[0].type_id == 588
        assert failures[0].dna == "dna-b"
        assert failures[0].variant == "full"
        assert failures[0].reason == "no-batch-result"

    def test_error_and_incomplete_stats_fail(self):
        results_by_id = {
            "587": {"id": "587", "error": "decode failed"},
            "588": {"id": "588", "stats": {"complete": False}},
        }
        produced, failures = evaluate_conversion_jobs(_jobs(), results_by_id, ShipModelVariant.BASE)
        assert produced == set()
        assert [failure.reason for failure in failures] == [
            "converter-error:decode failed",
            "incomplete",
        ]
        assert all(failure.variant == "base" for failure in failures)


class TestMergeVariantResults:
    def test_merges_across_shards(self):
        reports = [shard_report([{"id": "1"}]), shard_report([{"id": "2"}], index=2)]
        merged = merge_variant_results(reports)
        assert set(merged) == {"1", "2"}

    def test_later_shard_wins_on_duplicate_id(self):
        reports = [
            shard_report([{"id": "1", "stats": {"complete": False}}]),
            shard_report([{"id": "1", "stats": {"complete": True}}], index=2),
        ]
        merged = merge_variant_results(reports)
        assert merged["1"]["stats"]["complete"] is True

    def test_int_result_ids_normalized_to_strings(self):
        report = shard_report([{"id": 587, "stats": {"complete": True}}])
        merged = merge_variant_results([report])
        assert merged["587"]["stats"]["complete"] is True

    def test_results_without_id_skipped(self):
        merged = merge_variant_results([shard_report([{"stats": {}}, {"id": "9"}])])
        assert set(merged) == {"9"}


class TestShardFailureReporting:
    def test_failed_shard_marks_unreported_jobs_unverified(self):
        # A shard that exits nonzero after reporting only the first of two
        # jobs: the verified job still counts, the unreported job fails, and
        # the process error is captured for the diagnostics report.
        report = shard_report(
            [_verified_result("587", "dna-a")],
            index=3,
            returncode=1,
            stderr_tail="node blew up",
        )
        produced, failures = evaluate_conversion_jobs(
            _jobs(), merge_variant_results([report]), ShipModelVariant.FULL
        )
        assert produced == {"dna-a"}
        assert [failure.reason for failure in failures] == ["no-batch-result"]

        entry = shard_report_entry(report)
        assert entry["variant"] == "full"
        assert entry["index"] == 3
        assert entry["returncode"] == 1
        assert entry["stderr_tail"] == "node blew up"
        assert entry["results"] == 1
        assert entry["parse_error"] is None

    def test_missing_stats_file_reported(self):
        report = shard_report([], parse_error="converter wrote no stats report")
        entry = shard_report_entry(report)
        assert entry["parse_error"] == "converter wrote no stats report"
        assert entry["results"] == 0

    def test_corrupt_stats_file_reported(self):
        results, parse_error = parse_stats_report("garbage")
        report = shard_report(results, parse_error=parse_error)
        entry = shard_report_entry(report)
        assert entry["parse_error"] is not None
        assert entry["results"] == 0


class TestBuildConversionDiagnostics:
    def test_complete_run(self):
        report = shard_report([{"id": "587", "stats": {"complete": True}}])
        document = build_conversion_diagnostics(
            [report],
            [],
            converted_counts={ShipModelVariant.FULL: 3, ShipModelVariant.BASE: 3},
            cache_hit_counts={ShipModelVariant.FULL: 0, ShipModelVariant.BASE: 0},
        )
        assert document["complete"] is True
        assert document["converted"] == {"full": 3, "base": 3}
        assert document["cache_hits"] == {"full": 0, "base": 0}
        assert document["failures"] == []
        assert document["shards"][0]["stats"] == "stats_convert_full_main_1.json"
        assert document["jobs"] == [{"id": "587", "variant": "full", "stats": {"complete": True}}]

    def test_failed_run_is_incomplete_with_failures(self):
        failure = ConversionFailure(
            type_id=588, dna="dna-b", variant="full", reason="no-batch-result"
        )
        document = build_conversion_diagnostics(
            [shard_report([])],
            [failure],
            converted_counts={ShipModelVariant.FULL: 1, ShipModelVariant.BASE: 0},
            cache_hit_counts={ShipModelVariant.FULL: 0, ShipModelVariant.BASE: 0},
        )
        assert document["complete"] is False
        assert document["converted"] == {"full": 1, "base": 0}
        assert document["failures"] == [
            {"type_id": 588, "dna": "dna-b", "variant": "full", "reason": "no-batch-result"}
        ]

    def test_document_is_json_serializable(self):
        failure = ConversionFailure(type_id=588, dna="dna-b", variant="full", reason="incomplete")
        document = build_conversion_diagnostics(
            [shard_report([], returncode=1, stderr_tail="boom")],
            [failure],
            converted_counts={ShipModelVariant.FULL: 0, ShipModelVariant.BASE: 0},
            cache_hit_counts={ShipModelVariant.FULL: 2, ShipModelVariant.BASE: 2},
        )
        assert json.loads(json.dumps(document)) == document


class TestClassifyResolveError:
    def test_no_mesh_is_one_explicit_skip(self):
        failure, skip = classify_resolve_error(
            {
                "id": "95630",
                "dna": "cbc3_fn:caldarinavy:caldari",
                "error": 'DNA "..." produced no mesh',
                "errorCode": "NO_SOURCE_MESH",
            }
        )
        assert failure is None
        assert skip == {
            "type_id": 95630,
            "dna": "cbc3_fn:caldarinavy:caldari",
            "reason": "no-source-mesh",
        }

    def test_other_resolve_error_is_one_hard_failure(self):
        failure, skip = classify_resolve_error({"id": "1", "dna": "bad", "error": "invalid"})
        assert skip is None
        assert failure == ConversionFailure(1, "bad", "resolve", "resolve-error:invalid")

    def test_success_has_no_failure_or_skip(self):
        assert classify_resolve_error({"id": "1", "dna": "ok"}) == (None, None)


class TestRemoveStaleShipModelOutputs:
    def test_only_obsolete_full_and_base_variants_are_removed(self, tmp_path: Path):
        for name in [
            "1.full.glb",
            "1.base.glb",
            "2.full.glb",
            "2.base.glb",
            "3.glb",
            "notes.txt",
            "unexpected.full.glb",
            "4.full.glb.tmp-123",
        ]:
            (tmp_path / name).write_bytes(b"fixture")
        removed = remove_stale_ship_model_outputs(tmp_path, {2})
        assert removed == ["1.base.glb", "1.full.glb", "4.full.glb.tmp-123"]
        assert sorted(path.name for path in tmp_path.iterdir()) == [
            "2.base.glb",
            "2.full.glb",
            "3.glb",
            "notes.txt",
            "unexpected.full.glb",
        ]


class TestCacheEligible:
    def test_full_requires_staged_textures(self):
        assert cache_eligible(ShipModelVariant.FULL, textures_staged=True) is True
        assert cache_eligible(ShipModelVariant.FULL, textures_staged=False) is False

    def test_base_ignores_texture_staging(self):
        # BASE carries no texture identity, so a texture staging failure must
        # not gate its cache eligibility.
        assert cache_eligible(ShipModelVariant.BASE, textures_staged=False) is True


def test_incomplete_conversion_error_is_a_runtime_error():
    with pytest.raises(RuntimeError):
        raise IncompleteConversionError("587")


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__]))
