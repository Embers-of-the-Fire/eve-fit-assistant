from __future__ import annotations

from bootstrap.data.workspace.generate.static.implant_sets import MergedSet
from bootstrap.data.workspace.generate.static.implant_sets import SetMember
from bootstrap.data.workspace.generate.static.implant_sets import assign_set_ids
from bootstrap.data.workspace.generate.static.implant_sets import base_name
from bootstrap.data.workspace.generate.static.implant_sets import cluster_members
from bootstrap.data.workspace.generate.static.implant_sets import family_display_name
from bootstrap.data.workspace.generate.static.implant_sets import family_key
from bootstrap.data.workspace.generate.static.implant_sets import find_set_effects
from bootstrap.data.workspace.generate.static.implant_sets import merge_set_clusters
from bootstrap.data.workspace.generate.static.implant_sets import set_display_name


def test_find_set_effects_picks_up_set_bonus_and_implant_set():
    dogma_attributes = {
        66: {"name": "durationBonus"},
        838: {"name": "implantSetGuristas"},
        863: {"name": "implantSetHalo"},
        1932: {"name": "implantSetWarpSpeed"},
        3017: {"name": "ImplantSetNirvana"},
    }
    dogma_effects = {
        1397: {
            "effectName": "setBonusGuristas",
            "modifierInfo": [{"modifyingAttributeID": 838}],
        },
        5717: {
            "effectName": "implantSetWarpSpeed",
            "modifierInfo": [{"modifyingAttributeID": 1932}],
        },
        1577: {
            "effectName": "haloSetBonus",
            "modifierInfo": [{"modifyingAttributeID": 863}],
        },
        8013: {
            "effectName": "setBonusNirvana",
            "modifierInfo": [{"modifyingAttributeID": 3017}],
        },
        1256: {
            # Not a set-membership effect: modifies by a non-implantSet attribute.
            "effectName": "setBonusBloodraiderNosferatu",
            "modifierInfo": [{"modifyingAttributeID": 66}],
        },
        11: {
            "effectName": "shieldBoosting",
            "modifierInfo": [{"modifyingAttributeID": 100}],
        },
        9999: {
            "effectName": "setBonusNoModifier",
            "modifierInfo": [{}],
        },
    }

    assert find_set_effects(dogma_effects, dogma_attributes) == {
        1397: 838,
        5717: 1932,
        1577: 863,
        8013: 3017,
    }


def test_find_set_effects_handles_missing_fields():
    assert find_set_effects({1: {}}, {}) == {}
    assert find_set_effects({2: {"effectName": "setBonusX"}}, {3: {}}) == {}


def test_base_name_strips_slot_discriminator():
    assert base_name("High-grade Crystal Alpha") == "High-grade Crystal"
    assert base_name("Genolution Core Augmentation CA-1") == "Genolution Core Augmentation"
    assert base_name("SingleWord") == "SingleWord"


def test_set_display_name_common_prefix():
    names = [
        "High-grade Crystal Alpha",
        "High-grade Crystal Beta",
        "High-grade Crystal Omega",
    ]
    assert set_display_name(names) == "High-grade Crystal"


def test_set_display_name_trims_trailing_partial_token():
    names = [
        "Genolution Core Augmentation CA-1",
        "Genolution Core Augmentation CA-2",
    ]
    assert set_display_name(names) == "Genolution Core Augmentation"


def test_set_display_name_keeps_cjk_prefix():
    names = ["高级水晶体阿尔法", "高级水晶体欧米伽"]
    assert set_display_name(names) == "高级水晶体"


def test_set_display_name_strips_trailing_cjk_separator():
    # Real zh names: "高级水晶—阿尔法型", "低级辟邪 - 阿尔法型"
    assert set_display_name(["高级水晶—阿尔法型", "高级水晶—欧米伽型"]) == "高级水晶"
    assert set_display_name(["低级辟邪 - 阿尔法型", "低级辟邪 - 欧米伽型"]) == "低级辟邪"


def test_set_display_name_empty():
    assert set_display_name([]) == ""


def test_family_display_name():
    assert (
        family_display_name(["Low-grade Crystal", "Mid-grade Crystal", "High-grade Crystal"], "en")
        == "Crystal"
    )
    assert family_display_name(["低级水晶", "中级水晶", "高级水晶"], "zh") == "水晶"
    assert family_display_name(["低级辟邪", "高级辟邪"], "zh") == "辟邪"
    assert family_display_name(["Genolution Core Augmentation"], "en") == (
        "Genolution Core Augmentation"
    )
    assert family_display_name([], "en") == ""


def test_family_display_name_fallback_for_unknown_language():
    # No grade table: falls back to the longest common suffix at a token boundary.
    assert family_display_name(["Low-grade Crystal", "High-grade Crystal"], "fr") == "Crystal"


def test_family_key_strips_grade_token():
    assert family_key("High-grade Crystal") == "Crystal"
    assert family_key("Low-grade Grail") == "Grail"
    assert family_key("Genolution Core Augmentation") == "Genolution Core Augmentation"


def test_cluster_members_splits_grades():
    members = [
        SetMember(type_id=1, slot=1, set_value=1.15),
        SetMember(type_id=2, slot=2, set_value=1.15),
        SetMember(type_id=3, slot=1, set_value=1.025),
        SetMember(type_id=4, slot=2, set_value=1.025),
    ]
    names = {
        1: "High-grade Crystal Alpha",
        2: "High-grade Crystal Beta",
        3: "Low-grade Crystal Alpha",
        4: "Low-grade Crystal Beta",
    }

    clusters = cluster_members(members, names.get)
    cluster_type_ids = sorted(sorted(m.type_id for m in cluster) for cluster in clusters)
    assert cluster_type_ids == [[1, 2], [3, 4]]


def _talisman_like_members() -> tuple[dict[int, list[SetMember]], dict[int, str]]:
    """Mirror Talisman: one effect covering Alpha-Omega, another Alpha-Epsilon."""
    names = {}
    members_by_effect: dict[int, list[SetMember]] = {100: [], 200: []}
    grades = [("Low-grade", 1.025), ("Mid-grade", 1.1), ("High-grade", 1.15)]
    type_id = 0
    for grade, value in grades:
        for slot, greek in enumerate(["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Omega"], 1):
            type_id += 1
            names[type_id] = f"{grade} Talisman {greek}"
            members_by_effect[100].append(SetMember(type_id, slot, value))
            if slot <= 5:
                members_by_effect[200].append(SetMember(type_id, slot, value))
    return members_by_effect, names


def test_merge_set_clusters_merges_effects_of_same_family():
    members_by_effect, names = _talisman_like_members()

    sets = merge_set_clusters(members_by_effect, {100: 800, 200: 801}, names.get)

    assert len(sets) == 3
    for merged_set in sets:
        assert merged_set.effect_id == 100
        assert len(merged_set.members) == 6
        assert [m.slot for m in merged_set.members] == [1, 2, 3, 4, 5, 6]
    assert {s.display for s in sets} == {
        "Low-grade Talisman",
        "Mid-grade Talisman",
        "High-grade Talisman",
    }


def test_merge_set_clusters_drops_singletons():
    members_by_effect = {100: [SetMember(1, 1, 1.15)]}
    assert merge_set_clusters(members_by_effect, {100: 800}, lambda _: "Solo Implant") == []


def test_assign_set_ids_groups_families_and_ranks_grades():
    def make_set(effect_id, display, value):
        return MergedSet(
            effect_id=effect_id,
            display=display,
            members=[SetMember(type_id=1, slot=1, set_value=value)],
        )

    sets = [
        # Crystal family: one effect, three grades (given out of order).
        make_set(1397, "High-grade Crystal", 1.15),
        make_set(1397, "Low-grade Crystal", 1.025),
        make_set(1397, "Mid-grade Crystal", 1.1),
        # Navy family: grades spread over two different effects.
        make_set(4457, "High-grade Grail", 1.15),
        make_set(4460, "Low-grade Grail", 1.025),
        # Single-set family without a grade token.
        make_set(4867, "Genolution Core Augmentation", 1.5),
    ]

    assigned = assign_set_ids(sets)
    by_display = {s.display: set_id for set_id, s in assigned}

    crystal_ids = {by_display[d] // 100 for d in by_display if "Crystal" in d}
    assert len(crystal_ids) == 1
    grail_ids = {by_display[d] // 100 for d in by_display if "Grail" in d}
    assert len(grail_ids) == 1

    # Grade ranks ascend with set strength within each family.
    assert by_display["Low-grade Crystal"] % 100 == 0
    assert by_display["Mid-grade Crystal"] % 100 == 1
    assert by_display["High-grade Crystal"] % 100 == 2
    assert by_display["Low-grade Grail"] % 100 == 0
    assert by_display["High-grade Grail"] % 100 == 1
