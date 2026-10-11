"""Unit tests for the dual-track version model in bootstrap.config."""

from __future__ import annotations

import pytest

from bootstrap.config import ProjectVersion
from bootstrap.config import ReleaseVersion
from bootstrap.config import StableTrackVersion
from bootstrap.config import TestingTrackVersion
from bootstrap.config import semver_precedence_key
from bootstrap.remote.channel import Channel


def _make_version(
    testing: tuple[int, int, int, int] = (1, 2, 3, 4),
    stable: tuple[int, int, int] = (1, 2, 2),
    build: int = 5,
) -> ProjectVersion:
    return ProjectVersion(
        build=build,
        testing=TestingTrackVersion(
            major=testing[0], minor=testing[1], patch=testing[2], num=testing[3]
        ),
        stable=StableTrackVersion(major=stable[0], minor=stable[1], patch=stable[2]),
    )


class TestProjectVersionRendering:
    def test_render_semver_per_track(self) -> None:
        version = _make_version()
        assert version.render_semver(Channel.TESTING) == "1.2.3-beta.4"
        assert version.render_semver(Channel.STABLE) == "1.2.2"

    def test_render_full_appends_build(self) -> None:
        version = _make_version()
        assert version.render_full(Channel.TESTING) == "1.2.3-beta.4+5"
        assert version.render_full(Channel.STABLE) == "1.2.2+5"

    def test_render_full_omits_zero_build(self) -> None:
        version = _make_version(build=0)
        assert version.render_full(Channel.TESTING) == "1.2.3-beta.4"
        assert version.render_full(Channel.STABLE) == "1.2.2"

    def test_render_triplet_per_track(self) -> None:
        version = _make_version()
        assert version.render_triplet(Channel.TESTING) == "1.2.3"
        assert version.render_triplet(Channel.STABLE) == "1.2.2"

    def test_render_tag_per_track(self) -> None:
        version = _make_version()
        assert version.render_tag(Channel.TESTING) == "releases/v1.2.3-beta.4"
        assert version.render_tag(Channel.STABLE) == "releases/v1.2.2"

    def test_is_prerelease_per_track(self) -> None:
        version = _make_version()
        assert version.is_prerelease(Channel.TESTING)
        assert not version.is_prerelease(Channel.STABLE)

    def test_release_testing(self) -> None:
        release = _make_version().release(Channel.TESTING)
        assert release.track == Channel.TESTING
        assert release.semver == "1.2.3-beta.4"
        assert release.full == "1.2.3-beta.4+5"
        assert release.triplet == "1.2.3"
        assert release.tag == "releases/v1.2.3-beta.4"
        assert release.build == 5
        assert release.is_prerelease
        assert release.default_channels == ["testing"]

    def test_release_stable(self) -> None:
        release = _make_version().release(Channel.STABLE)
        assert release.track == Channel.STABLE
        assert release.semver == "1.2.2"
        assert release.full == "1.2.2+5"
        assert release.triplet == "1.2.2"
        assert release.tag == "releases/v1.2.2"
        assert release.build == 5
        assert not release.is_prerelease
        assert release.default_channels == ["stable"]


class TestReleaseVersionParse:
    def test_testing_with_counter(self) -> None:
        parsed = ReleaseVersion.parse("1.0.0-beta.7")
        assert parsed.track == Channel.TESTING
        assert parsed.semver == "1.0.0-beta.7"
        assert parsed.triplet == "1.0.0"
        assert parsed.tag == "releases/v1.0.0-beta.7"
        assert parsed.full == "1.0.0-beta.7"
        assert parsed.build == 0

    def test_bare_beta_defaults_to_num_one(self) -> None:
        parsed = ReleaseVersion.parse("1.0.0-beta")
        assert parsed.track == Channel.TESTING
        assert parsed.semver == "1.0.0-beta.1"

    def test_stable_with_build_metadata(self) -> None:
        parsed = ReleaseVersion.parse("1.0.0+42")
        assert parsed.track == Channel.STABLE
        assert parsed.semver == "1.0.0"
        assert parsed.full == "1.0.0+42"
        assert parsed.build == 42

    def test_testing_with_build_metadata(self) -> None:
        parsed = ReleaseVersion.parse("1.0.0-beta.7+3")
        assert parsed.track == Channel.TESTING
        assert parsed.build == 3
        assert parsed.full == "1.0.0-beta.7+3"

    def test_build_argument_used_when_no_suffix(self) -> None:
        parsed = ReleaseVersion.parse("1.0.0", build=9)
        assert parsed.build == 9
        assert parsed.full == "1.0.0+9"

    def test_invalid_core(self) -> None:
        with pytest.raises(ValueError, match="Invalid version"):
            ReleaseVersion.parse("1.0")

    def test_non_beta_label_rejected(self) -> None:
        with pytest.raises(ValueError, match="Invalid prerelease label"):
            ReleaseVersion.parse("1.0.0-alpha.1")

    def test_bad_prerelease_counter(self) -> None:
        with pytest.raises(ValueError, match="Invalid prerelease counter"):
            ReleaseVersion.parse("1.0.0-beta.x")

    def test_bad_build_metadata(self) -> None:
        with pytest.raises(ValueError, match="Invalid build metadata"):
            ReleaseVersion.parse("1.0.0+abc")

    def test_equality(self) -> None:
        assert ReleaseVersion.parse("1.0.0-beta.7") == ReleaseVersion.parse("1.0.0-beta.7")
        assert ReleaseVersion.parse("1.0.0-beta.7") != ReleaseVersion.parse("1.0.0-beta.8")
        assert ReleaseVersion.parse("1.0.0") != ReleaseVersion.parse("1.0.0-beta.1")


class TestLegacyMigration:
    def test_legacy_flat_dict_migrates(self) -> None:
        version = ProjectVersion.model_validate(
            {
                "major": 1,
                "minor": 2,
                "patch": 3,
                "pre_label": "beta",
                "pre_num": 4,
                "build": 5,
                "data_schema": 2,
            }
        )
        assert version.build == 5
        assert version.data_schema == 2
        assert version.testing == TestingTrackVersion(major=1, minor=2, patch=3, num=4)
        assert version.stable == StableTrackVersion(major=0, minor=0, patch=0)

    def test_legacy_dict_without_pre_fields(self) -> None:
        version = ProjectVersion.model_validate({"major": 0, "minor": 1, "patch": 0})
        assert version.testing == TestingTrackVersion(major=0, minor=1, patch=0, num=0)
        assert version.stable == StableTrackVersion(major=0, minor=0, patch=0)
        assert version.build == 0
        assert version.data_schema == 2

    def test_new_schema_round_trip(self) -> None:
        version = ProjectVersion.model_validate(
            {
                "build": 5,
                "testing": {"major": 1, "minor": 2, "patch": 3, "num": 4},
                "stable": {"major": 1, "minor": 2, "patch": 2},
            }
        )
        assert version.render_semver(Channel.TESTING) == "1.2.3-beta.4"
        assert version.render_semver(Channel.STABLE) == "1.2.2"

    def test_negative_component_rejected(self) -> None:
        with pytest.raises(ValueError, match="major must be >= 0"):
            TestingTrackVersion(major=-1, minor=0, patch=0)

    def test_negative_num_rejected(self) -> None:
        with pytest.raises(ValueError, match="num must be >= 0"):
            TestingTrackVersion(major=1, minor=0, patch=0, num=-1)

    def test_negative_build_rejected(self) -> None:
        with pytest.raises(ValueError, match="build must be >= 0"):
            _make_version(build=-1)


class TestSemverPrecedenceKey:
    def test_release_outranks_prerelease(self) -> None:
        assert semver_precedence_key("1.0.0") > semver_precedence_key("1.0.0-beta.99")

    def test_numeric_counters_compare_numerically(self) -> None:
        assert semver_precedence_key("1.0.0-beta.10") > semver_precedence_key("1.0.0-beta.9")

    def test_build_metadata_ignored(self) -> None:
        assert semver_precedence_key("1.2.3+1") == semver_precedence_key("1.2.3+999")

    def test_invalid_core_raises(self) -> None:
        with pytest.raises(ValueError, match="Invalid semver core"):
            semver_precedence_key("1.0.0.0")


class TestTrackOrderHolds:
    def test_testing_above_stable(self) -> None:
        assert _make_version().track_order_holds()

    def test_beta_zero_rollover_outranks_stable(self) -> None:
        version = _make_version(testing=(1, 7, 0, 0), stable=(1, 6, 5))
        assert version.track_order_holds()

    def test_testing_below_stable_fails(self) -> None:
        version = _make_version(testing=(1, 2, 3, 1), stable=(1, 2, 3))
        assert not version.track_order_holds()

    def test_equal_triplet_fails(self) -> None:
        version = _make_version(testing=(1, 2, 2, 1), stable=(1, 2, 2))
        assert not version.track_order_holds()
