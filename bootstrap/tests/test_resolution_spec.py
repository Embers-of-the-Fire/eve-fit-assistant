"""Tests for the RRS spec (data/schema/resource_resolution.toml) and the
derived FORCE/NON_FORCE stamping of generated resource snapshots."""

from __future__ import annotations

from typing import ClassVar

import pytest

from pydantic import ValidationError

import bootstrap.resolution

from bootstrap.resolution import ResolutionRule
from bootstrap.resolution import ResolutionSpec
from bootstrap.resolution import is_lazy_resource
from bootstrap.resolution import resolution_spec
from bootstrap.resolution import rule_matches_path
from bootstrap.resolution import rule_stamps_lazy
from bootstrap.resolution import split_pattern


@pytest.fixture(autouse=True)
def _reset_spec_cache(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(bootstrap.resolution, "_SPEC", None)


def _spec_dict(**overrides: object) -> dict:
    base: dict = {
        "version": 1,
        "context": [{"name": "locale", "type": "String"}],
        "vocabulary": {
            "scheme": "resource://",
            "legacy_localization_db": "localization/localization.db",
            "localization_locales_prefix": "localization/locales/",
            "static_images_prefix": "static/images/",
            "static_models_prefix": "static/models/",
            "locale_placeholder": "locale",
        },
        "rules": [{"prefix": "static/images/", "resolution": "lazy"}],
    }
    base.update(overrides)
    return base


def _custom_spec(monkeypatch: pytest.MonkeyPatch, **vocab_overrides: str) -> ResolutionSpec:
    """Swap in the real spec with vocabulary overrides applied."""
    spec = resolution_spec()
    custom = spec.model_copy(
        update={"vocabulary": spec.vocabulary.model_copy(update=vocab_overrides)}
    )
    monkeypatch.setattr(bootstrap.resolution, "_SPEC", custom)
    return custom


class TestSpecFile:
    def test_repository_spec_loads(self) -> None:
        spec = resolution_spec()
        assert spec.version == 2
        assert [field.name for field in spec.context] == ["locale"]
        assert spec.vocabulary.scheme == "resource://"
        assert len(spec.rules) == 4

    def test_rule_literals_match_vocabulary(self) -> None:
        """Pin the agreement between rule matchers and the vocabulary.

        The rules repeat vocabulary strings as literals; if the vocabulary
        moves, the rules must move with it or the stamped policy and the
        generated Dart evaluator silently diverge from the resource layout.
        """
        spec = resolution_spec()
        vocab = spec.vocabulary
        exact_rules = {r.exact: r for r in spec.rules if r.exact is not None}
        prefix_rules = {r.prefix for r in spec.rules if r.prefix is not None}
        pattern_rules = {r.pattern for r in spec.rules if r.pattern is not None}
        assert vocab.legacy_localization_db in exact_rules
        assert (
            exact_rules[vocab.legacy_localization_db].excluded_when_prefix_present
            == vocab.localization_locales_prefix
        )
        assert f"{vocab.localization_locales_prefix}{{{vocab.locale_placeholder}}}.db" in (
            pattern_rules
        )
        assert vocab.static_images_prefix in prefix_rules
        assert vocab.static_models_prefix in prefix_rules


class TestRuleValidation:
    def test_exactly_one_matcher_required(self) -> None:
        with pytest.raises(ValidationError):
            ResolutionRule(resolution="eager")
        with pytest.raises(ValidationError):
            ResolutionRule(exact="a", prefix="b", resolution="eager")

    def test_resolution_xor_context_pair(self) -> None:
        with pytest.raises(ValidationError):
            ResolutionRule(prefix="a", resolution="eager", on_context_match="lazy")
        with pytest.raises(ValidationError):
            ResolutionRule(prefix="a")

    def test_context_pair_must_be_complete(self) -> None:
        with pytest.raises(ValidationError):
            ResolutionRule(pattern="a/{locale}.db", on_context_match="eager")

    def test_context_pair_requires_pattern(self) -> None:
        with pytest.raises(ValidationError):
            ResolutionRule(prefix="a/", on_context_match="eager", on_context_mismatch="lazy")

    def test_excluded_when_requires_static_resolution(self) -> None:
        with pytest.raises(ValidationError):
            ResolutionRule(
                pattern="a/{locale}.db",
                on_context_match="eager",
                on_context_mismatch="lazy",
                excluded_when_prefix_present="b/",
            )

    def test_pattern_placeholder_must_be_a_context_field(self) -> None:
        with pytest.raises(ValidationError, match="unknown context field"):
            ResolutionSpec.model_validate(
                _spec_dict(
                    rules=[
                        {
                            "pattern": "a/{unknown}.db",
                            "on_context_match": "eager",
                            "on_context_mismatch": "lazy",
                        }
                    ]
                )
            )

    def test_pattern_needs_exactly_one_placeholder(self) -> None:
        with pytest.raises(ValidationError):
            ResolutionSpec.model_validate(
                _spec_dict(rules=[{"pattern": "a/plain.db", "resolution": "lazy"}])
            )

    def test_duplicate_context_fields_rejected(self) -> None:
        with pytest.raises(ValidationError, match="duplicate context field"):
            ResolutionSpec.model_validate(
                _spec_dict(
                    context=[
                        {"name": "locale", "type": "String"},
                        {"name": "locale", "type": "String"},
                    ]
                )
            )

    def test_empty_rules_rejected(self) -> None:
        with pytest.raises(ValidationError, match="must not be empty"):
            ResolutionSpec.model_validate(_spec_dict(rules=[]))

    def test_version_must_be_positive(self) -> None:
        with pytest.raises(ValidationError):
            ResolutionSpec.model_validate(_spec_dict(version=0))


class TestMatchingAndStampDerivation:
    def test_split_pattern(self) -> None:
        assert split_pattern("localization/locales/{locale}.db") == (
            "localization/locales/",
            "locale",
            ".db",
        )

    def test_pattern_family_matches_on_literal_head(self) -> None:
        rule = ResolutionRule(
            pattern="localization/locales/{locale}.db",
            on_context_match="eager",
            on_context_mismatch="lazy",
        )
        assert rule_matches_path(rule, "localization/locales/en.db")
        # The family branch mirrors the generated Dart mismatch branch: any
        # path under the head prefix belongs to the family.
        assert rule_matches_path(rule, "localization/locales/zh-tw.db")
        assert not rule_matches_path(rule, "localization/localization.db")

    def test_excluded_capable_rule_stamps_force(self) -> None:
        # excluded resources exist *for* pre-RRS clients; they must stay FORCE.
        rule = ResolutionRule(
            exact="localization/localization.db",
            resolution="eager",
            excluded_when_prefix_present="localization/locales/",
        )
        assert not rule_stamps_lazy(rule)

    def test_context_lazy_rule_stamps_lazy(self) -> None:
        rule = ResolutionRule(
            pattern="localization/locales/{locale}.db",
            on_context_match="eager",
            on_context_mismatch="lazy",
        )
        assert rule_stamps_lazy(rule)

    def test_static_resolutions_stamp_directly(self) -> None:
        assert rule_stamps_lazy(ResolutionRule(prefix="a/", resolution="lazy"))
        assert not rule_stamps_lazy(ResolutionRule(prefix="a/", resolution="eager"))
        assert not rule_stamps_lazy(ResolutionRule(prefix="a/", resolution="excluded"))


class TestIsLazyResource:
    def test_spec_classification(self) -> None:
        assert is_lazy_resource("resource://static/images/icons/1.png")
        assert is_lazy_resource("resource://static/images/graphics/2.png")
        assert is_lazy_resource("resource://static/models/ships/587.glb")
        assert is_lazy_resource("resource://localization/locales/en.db")
        assert not is_lazy_resource("resource://static/collection.pb2")
        assert not is_lazy_resource("resource://agent/agent_resource.db")

    def test_legacy_combined_db_stays_force(self) -> None:
        # Released native clients open it via a direct file path that cannot
        # fetch lazily; the derivation keeps it FORCE although the RRS
        # resolves it excluded when per-locale replacements exist.
        assert not is_lazy_resource("resource://localization/localization.db")

    def test_unknown_resources_fail_closed_to_force(self) -> None:
        assert not is_lazy_resource("resource://future/unknown.blob")

    def test_custom_scheme(self, monkeypatch: pytest.MonkeyPatch) -> None:
        _custom_spec(monkeypatch, scheme="custom://")
        assert is_lazy_resource("custom://static/images/icons/1.png")
        # The spec scheme no longer strips: the path keeps its prefix.
        assert not is_lazy_resource("resource://static/images/icons/1.png")


class TestMakeResourceIndex:
    _entries: ClassVar[list[tuple[str, str, int]]] = [
        ("resource://static/collection.pb2", "aa" * 32, 10),
        ("resource://static/images/icons/1.png", "bb" * 32, 20),
        ("resource://static/images/graphics/2.png", "cc" * 32, 30),
        ("resource://static/models/ships/587.full.glb", "ab" * 32, 35),
        ("resource://localization/localization.db", "dd" * 32, 40),
        ("resource://localization/locales/en.db", "ff" * 32, 60),
        ("resource://agent/agent_resource.db", "ee" * 32, 50),
    ]

    def test_emits_policy_aware_format_without_touching_schema_version(self) -> None:
        from bootstrap.remote.models import RESOURCE_INDEX_FORMAT_VERSION
        from bootstrap.remote.models import make_resource_index

        index = make_resource_index(self._entries)
        # schema_version is reserved for the remote storage protocol.
        assert index.schema_version == 1
        # Format 3: snapshots may carry static/models/ entries, which
        # format-2 clients would misclassify as eager.
        assert index.format_version == RESOURCE_INDEX_FORMAT_VERSION == 3

    def test_stamp_matches_rrs_derivation(self) -> None:
        from bootstrap.remote.models import make_resource_index

        index = make_resource_index(self._entries)
        policy = {e.resource_id: e.download_policy for e in index.entries}
        force = index.DownloadPolicy.FORCE
        non_force = index.DownloadPolicy.NON_FORCE
        assert policy["resource://static/collection.pb2"] == force
        assert policy["resource://localization/localization.db"] == force
        assert policy["resource://agent/agent_resource.db"] == force
        assert policy["resource://static/images/icons/1.png"] == non_force
        assert policy["resource://static/images/graphics/2.png"] == non_force
        assert policy["resource://static/models/ships/587.full.glb"] == non_force
        assert policy["resource://localization/locales/en.db"] == non_force

    def test_custom_spec_drives_stamping(self, monkeypatch: pytest.MonkeyPatch) -> None:
        from bootstrap.remote.models import make_resource_index

        monkeypatch.setattr(
            bootstrap.resolution,
            "_SPEC",
            ResolutionSpec.model_validate(
                _spec_dict(
                    vocabulary={
                        "scheme": "custom://",
                        "legacy_localization_db": "i18n/combined.db",
                        "localization_locales_prefix": "i18n/locales/",
                        "static_images_prefix": "assets/images/",
                        "static_models_prefix": "assets/models/",
                        "locale_placeholder": "locale",
                    },
                    rules=[
                        {
                            "pattern": "i18n/locales/{locale}.db",
                            "on_context_match": "eager",
                            "on_context_mismatch": "lazy",
                        },
                        {"prefix": "assets/images/", "resolution": "lazy"},
                    ],
                )
            ),
        )
        entries = [
            ("custom://static/collection.pb2", "aa" * 32, 10),
            ("custom://assets/images/icons/1.png", "bb" * 32, 20),
            ("custom://i18n/locales/en.db", "cc" * 32, 30),
            ("custom://i18n/combined.db", "dd" * 32, 40),
        ]
        index = make_resource_index(entries)
        policy = {e.resource_id: e.download_policy for e in index.entries}
        force = index.DownloadPolicy.FORCE
        non_force = index.DownloadPolicy.NON_FORCE
        assert policy["custom://assets/images/icons/1.png"] == non_force
        assert policy["custom://i18n/locales/en.db"] == non_force
        assert policy["custom://i18n/combined.db"] == force
        assert policy["custom://static/collection.pb2"] == force

    def test_roundtrip_preserves_policy(self) -> None:
        from bootstrap.data.schema import resource_index_pb2
        from bootstrap.remote.models import RESOURCE_INDEX_FORMAT_VERSION
        from bootstrap.remote.models import make_resource_index

        index = make_resource_index(self._entries)
        parsed = resource_index_pb2.ResourceIndex.FromString(index.SerializeToString())
        assert parsed.format_version == RESOURCE_INDEX_FORMAT_VERSION
        assert {e.resource_id: e.download_policy for e in parsed.entries} == {
            e.resource_id: e.download_policy for e in index.entries
        }


class TestRetiredConfigTables:
    def _config_dict(self, **overrides: object) -> dict:
        base: dict = {
            "localizations": {
                "default": "en",
                "supported": ["en", "zh"],
                "translation": {"en": "English", "zh": "简体中文"},
            },
            "paths": {"log": "data/log"},
            "version": {"major": 0, "minor": 1, "patch": 0, "build": 1},
        }
        base.update(overrides)
        return base

    def test_download_table_is_rejected(self) -> None:
        from bootstrap.config import ProjectConfiguration

        with pytest.raises(ValidationError, match=r"resource_resolution\.toml"):
            ProjectConfiguration.model_validate(
                self._config_dict(download={"lazy_prefixes": ["static/images/"]})
            )

    def test_resolution_table_is_rejected(self) -> None:
        from bootstrap.config import ProjectConfiguration

        with pytest.raises(ValidationError, match=r"resource_resolution\.toml"):
            ProjectConfiguration.model_validate(
                self._config_dict(resolution={"scheme": "custom://"})
            )
