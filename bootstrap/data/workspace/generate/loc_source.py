"""Shared FSD localization loading with curated patch support.

CCP's non-English FSD localization lags behind new content (e.g. the
"Advanced Carriers" market group name has no zh string, surfacing as
`LOC[1054541]` in the app). Workspaces can ship curated overrides in
`patches/localization.yaml`, keyed by locale and then by the English source
text so entries survive message-ID changes:

```yaml
zh:
  "Advanced Carriers": "高级航空母舰"
```

Patches only fill strings that are missing or empty in the target locale;
they never override upstream text.
"""

from __future__ import annotations

import pickle

from dataclasses import dataclass
from typing import TYPE_CHECKING

from bootstrap.localization import to_native_localization


if TYPE_CHECKING:
    from bootstrap.data.workspace.generate import GeneratorDatasource
    from bootstrap.localization import LocalizationType


#: Name of the optional per-workspace patch file (`patches/localization.yaml`).
LOCALIZATION_PATCH_KEY = "localization"


@dataclass(frozen=True)
class LocalizationPatchReport:
    """Outcome of applying curated localization patches to one locale."""

    #: Message ids filled by patch entries (id -> patched text).
    filled: dict[int, str]
    #: Patch entries whose English source text no longer resolves to a missing
    #: string (already translated upstream, or the source text changed).
    stale_keys: list[str]


async def load_localized_strings(
    ws_data: GeneratorDatasource, lang: LocalizationType
) -> dict[int, str]:
    """Loads the raw FSD localization strings for one locale."""
    resource = ws_data.resources.res.get_resource(
        f"res:/localizationfsd/localization_fsd_{to_native_localization(lang)}.pickle"
    )
    async with resource.open() as f:
        _lang_code, loc = pickle.loads(await f.read())
    return {int(key): value[0] for key, value in loc.items()}


def load_localization_patch_map(
    ws_data: GeneratorDatasource, lang: LocalizationType
) -> dict[str, str]:
    """Loads curated patches for one locale from `patches/localization.yaml`.

    Returns an empty map when the workspace ships no localization patches.
    """
    patches = ws_data.resources.patches.get_optional(LOCALIZATION_PATCH_KEY, "yaml") or {}
    entries = patches.get(lang) or {}
    return {str(key): str(value) for key, value in entries.items() if value}


def apply_localization_patches(
    strings: dict[int, str],
    reference: dict[int, str],
    patch_map: dict[str, str],
) -> LocalizationPatchReport:
    """Fills missing/empty strings in `strings` using curated `patch_map`.

    `reference` is the default locale's strings (en); `patch_map` is keyed by
    the reference text so entries survive message-ID changes. Existing
    non-empty strings are never overridden. `strings` is mutated in place.
    """
    filled: dict[int, str] = {}
    used_keys: set[str] = set()
    for message_id, ref_text in reference.items():
        if not ref_text or strings.get(message_id):
            continue
        translation = patch_map.get(ref_text)
        if translation is None:
            continue
        strings[message_id] = translation
        filled[message_id] = translation
        used_keys.add(ref_text)
    return LocalizationPatchReport(filled=filled, stale_keys=sorted(set(patch_map) - used_keys))


def find_missing_strings(
    strings: dict[int, str], reference: dict[int, str]
) -> list[tuple[int, str]]:
    """(id, reference text) pairs still missing/empty in `strings`, sorted by id."""
    return sorted(
        (message_id, ref_text)
        for message_id, ref_text in reference.items()
        if ref_text and not strings.get(message_id)
    )
