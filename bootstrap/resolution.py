"""Resource Resolution Schema (RRS) spec loader and stamp derivation.

The spec lives in ``data/schema/resource_resolution.toml`` and is the single
source of truth for both the app's download resolution (via the Dart codegen
in ``bootstrap.data.codegen.resource_resolution``) and the FORCE/NON_FORCE
``download_policy`` the pipeline stamps into ``ResourceIndex`` snapshots for
pre-RRS clients.

The stamp is *derived* from the rules, never configured separately:

- a rule that can resolve ``excluded`` stamps FORCE — ``excluded`` resources
  are superseded payloads retained *for* older clients, which do not
  understand supersession and must keep downloading them eagerly;
- a rule that can resolve ``lazy`` in some context (and never ``excluded``)
  stamps NON_FORCE — lazy already asserts the resource is fetchable on
  demand, and pre-RRS clients are context-free;
- anything else (unconditional ``eager``, and the implicit final rule)
  stamps FORCE.
"""

from __future__ import annotations

import re
import tomllib

from pathlib import Path
from pathlib import PurePosixPath
from pathlib import PureWindowsPath
from typing import Literal

from pydantic import BaseModel
from pydantic import ConfigDict
from pydantic import Field
from pydantic import field_validator
from pydantic import model_validator

from bootstrap.constant import PROJECT_ROOT


#: Path of the RRS spec, relative to the project root.
SPEC_PATH: Path = PROJECT_ROOT / "data" / "schema" / "resource_resolution.toml"

#: The resolutions a rule can yield. Mirrored by the generated Dart
#: ``ResourceResolution`` enum; ``excluded`` is reachable only via a static
#: resolution or ``excluded_when_prefix_present``.
Resolution = Literal["eager", "lazy", "excluded"]

#: Resolutions allowed on the context-match pair; ``excluded`` is
#: condition-driven, not context-driven.
ContextResolution = Literal["eager", "lazy"]

_PLACEHOLDER_RE = re.compile(r"\{([^{}]+)\}")


class ResolutionContextField(BaseModel):
    """One client-side state field available to rule evaluation."""

    model_config = ConfigDict(populate_by_name=True)

    #: Field name; patterns reference it as ``{name}``.
    name: str
    #: Dart type of the generated ``ResourceResolutionContext`` field.
    type: str
    #: Dart import for non-built-in types; omitted for built-ins.
    import_: str | None = Field(default=None, alias="import")
    #: Doc comment emitted on the generated Dart field.
    doc: str = ""


class ResolutionVocabulary(BaseModel):
    """Shared resource-resolution vocabulary (paths, prefixes, placeholders).

    Single source of truth for the strings the app and the data pipeline must
    agree on: resource-id scheme, the legacy combined localization database
    path, the per-locale database prefix, the static images prefix, and the
    resolution-context placeholder name. Generated into Dart by
    ``bootstrap.data.codegen.resource_resolution``.
    """

    model_config = ConfigDict(validate_default=True)

    #: URI scheme prefix of checkout resource ids.
    scheme: str
    #: Path (relative to the scheme) of the legacy combined localization db.
    legacy_localization_db: str
    #: Path prefix (relative to the scheme) of the per-locale databases.
    localization_locales_prefix: str
    #: Path prefix (relative to the scheme) of the static image resources.
    static_images_prefix: str
    #: Resolution-context placeholder embedded in resource-id patterns.
    locale_placeholder: str

    @field_validator("legacy_localization_db", "localization_locales_prefix")
    @classmethod
    def _validate_relative_posix_path(cls, value: str) -> str:
        """Reject paths that could escape the generation output directory.

        The localization generator creates, unlinks, and recreates SQLite files
        at these paths joined to the generated workspace, so they must stay
        relative POSIX paths without ``..`` segments. Backslashes are rejected
        too: ``PurePosixPath`` treats them as literal characters, but on
        Windows hosts they act as path separators once the value is joined to
        a ``pathlib.Path``, re-opening traversal via e.g. ``..\\escape.db``.
        Drive-qualified Windows paths such as ``C:/escape.db`` or
        ``C:escape.db`` are rejected for the same reason: ``PurePosixPath``
        accepts them as relative, but native Windows joins resolve them
        against the drive root or the drive's current directory.
        """
        path = PurePosixPath(value)
        if (
            "\\" in value
            or path.is_absolute()
            or ".." in path.parts
            or PureWindowsPath(value).drive
        ):
            raise ValueError(
                f"must be a relative POSIX path without '..' segments, "
                f"backslashes, or Windows drive components, got {value!r}"
            )
        return value


class ResolutionRule(BaseModel):
    """One ordered RRS rule: a matcher plus a resolution or context pair."""

    #: Matches when the resource path equals this literal.
    exact: str | None = None
    #: Matches when the resource path starts with this literal.
    prefix: str | None = None
    #: Matches a resource family: the literal head before the single
    #: ``{context-field}`` placeholder. The context-match branch compares the
    #: full pattern with the context value substituted.
    pattern: str | None = None

    #: Static resolution for matched resources.
    resolution: Resolution | None = None
    #: Resolution when the pattern matches with the context value substituted.
    on_context_match: ContextResolution | None = None
    #: Resolution for other members of the pattern's family.
    on_context_mismatch: ContextResolution | None = None
    #: Resolve to ``excluded`` when the index contains any entry under this
    #: path prefix (superseded resources retained for older clients).
    excluded_when_prefix_present: str | None = None

    @model_validator(mode="after")
    def _validate_rule(self) -> ResolutionRule:
        matchers = [self.exact is not None, self.prefix is not None, self.pattern is not None]
        if sum(matchers) != 1:
            raise ValueError("a rule needs exactly one of exact / prefix / pattern")
        has_static = self.resolution is not None
        has_pair = self.on_context_match is not None or self.on_context_mismatch is not None
        if has_static == has_pair:
            raise ValueError(
                "a rule needs either a static resolution or the "
                "on_context_match / on_context_mismatch pair"
            )
        if has_pair and (self.on_context_match is None or self.on_context_mismatch is None):
            raise ValueError("on_context_match and on_context_mismatch must be set together")
        if has_pair and self.pattern is None:
            raise ValueError("the on_context_* pair requires a pattern matcher")
        if self.excluded_when_prefix_present is not None and not has_static:
            raise ValueError("excluded_when_prefix_present requires a static resolution")
        return self


class ResolutionSpec(BaseModel):
    """The parsed ``data/schema/resource_resolution.toml``."""

    model_config = ConfigDict(validate_default=True)

    #: RRS version shipped with the app; codegen'd as
    #: ``kResourceResolutionSchemaVersion``.
    version: int
    #: Client-side state fields available to rule evaluation.
    context: list[ResolutionContextField]
    #: Shared resource-layout vocabulary.
    vocabulary: ResolutionVocabulary
    #: Ordered rule list; first match wins. The implicit final rule resolves
    #: everything else to ``eager``.
    rules: list[ResolutionRule]

    @field_validator("version")
    @classmethod
    def _validate_version(cls, value: int) -> int:
        if value < 1:
            raise ValueError(f"version must be >= 1, got {value}")
        return value

    @model_validator(mode="after")
    def _validate_spec(self) -> ResolutionSpec:
        names = [field.name for field in self.context]
        if len(names) != len(set(names)):
            raise ValueError(f"duplicate context field names: {names}")
        if not self.rules:
            raise ValueError("the rule list must not be empty")
        known = set(names)
        for rule in self.rules:
            if rule.pattern is None:
                continue
            placeholders = _PLACEHOLDER_RE.findall(rule.pattern)
            if len(placeholders) != 1:
                raise ValueError(
                    f"pattern {rule.pattern!r} must contain exactly one "
                    "{context-field} placeholder"
                )
            if placeholders[0] not in known:
                raise ValueError(
                    f"pattern {rule.pattern!r} references unknown context field "
                    f"{placeholders[0]!r} (known: {sorted(known)})"
                )
        return self


_SPEC: ResolutionSpec | None = None


def resolution_spec() -> ResolutionSpec:
    """Return the parsed RRS spec, loading and caching it on first access."""
    global _SPEC
    if _SPEC is None:
        with SPEC_PATH.open("rb") as f:
            _SPEC = ResolutionSpec.model_validate(tomllib.load(f))
    return _SPEC


def resolution_vocabulary() -> ResolutionVocabulary:
    """The shared resource-layout vocabulary from the RRS spec."""
    return resolution_spec().vocabulary


def split_pattern(pattern: str) -> tuple[str, str, str]:
    """Split a rule pattern into (head, context field name, tail)."""
    match = _PLACEHOLDER_RE.search(pattern)
    assert match is not None  # guaranteed by spec validation
    return pattern[: match.start()], match.group(1), pattern[match.end() :]


def rule_matches_path(rule: ResolutionRule, path: str) -> bool:
    """Whether [path] (relative to the scheme) belongs to [rule]'s family.

    Pattern rules match on their literal head, mirroring the generated Dart
    evaluator's context-mismatch (family) branch.
    """
    if rule.exact is not None:
        return path == rule.exact
    if rule.prefix is not None:
        return path.startswith(rule.prefix)
    assert rule.pattern is not None
    head, _, _ = split_pattern(rule.pattern)
    return path.startswith(head)


def rule_stamps_lazy(rule: ResolutionRule) -> bool:
    """Whether resources matched by [rule] are stamped NON_FORCE.

    The derivation: a rule stamps NON_FORCE iff it can resolve ``lazy`` in
    some context and can never resolve ``excluded``. ``excluded`` stamps
    FORCE because exclusion exists for pre-RRS clients, which must keep
    downloading the resource eagerly.
    """
    if rule.excluded_when_prefix_present is not None:
        return False
    if rule.resolution is not None:
        return rule.resolution == "lazy"
    return "lazy" in (rule.on_context_match, rule.on_context_mismatch)


def is_lazy_resource(resource_id: str) -> bool:
    """Whether [resource_id] is stamped NON_FORCE in generated snapshots.

    Evaluates the RRS rule list from the spec; resources matching no rule
    fall through to the implicit final ``eager`` rule (FORCE).
    """
    spec = resolution_spec()
    path = resource_id.removeprefix(spec.vocabulary.scheme)
    for rule in spec.rules:
        if rule_matches_path(rule, path):
            return rule_stamps_lazy(rule)
    return False
