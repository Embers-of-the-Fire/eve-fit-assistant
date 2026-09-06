import "package:efa_proto/fit.pb.dart";
import "package:efa_proto/market_groups.pb.dart" as pb_market;
import "package:efa_proto/types.pb.dart" as pb_types;
import "package:efa_proto/utils.pb.dart" as pb_utils;
import "package:eve_fit_assistant/pages/fit/components/booster_select_list.dart";
import "package:flutter_test/flutter_test.dart";

pb_types.Type _type(int typeId, {bool published = true, int marketGroupId = 0}) =>
    pb_types.Type(typeId: typeId, published: published, marketGroupId: marketGroupId);

pb_market.MarketGroup _marketGroup(
  int id, {
  int nameId = 0,
  int parentGroupId = 0,
  List<int> groups = const [],
  List<int> types = const [],
}) {
  final group = pb_market.MarketGroup(
    marketGroupId: id,
    marketGroupName: pb_utils.LocalizationID(id: nameId),
    groups: groups,
    types: types,
  );
  if (parentGroupId != 0) group.parentGroupId = parentGroupId;
  return group;
}

void main() {
  // Market tree mirroring the real bundle layout:
  //   24 Implants & Boosters
  //   +- 977 Booster
  //   |  +- 2488 "Booster Slot 01"
  //   |  |  `- 2491 "Blue Pill" (types 100, 101)
  //   |  `- 2489 "Booster Slot 02"
  //   |     `- 2496 "Drop" (type 200)
  //   `- 2487 "Cerebral Accelerators" (type 400)
  const mgRoot = 24;
  const mgBoosters = 977;
  const mgSlot1 = 2488;
  const mgBluePill = 2491;
  const mgSlot2 = 2489;
  const mgDrop = 2496;
  const mgAccelerators = 2487;

  final marketGroups = [
    _marketGroup(mgRoot, nameId: 24, groups: [mgBoosters, mgAccelerators]),
    _marketGroup(mgBoosters, nameId: 977, parentGroupId: mgRoot, groups: [mgSlot1, mgSlot2]),
    _marketGroup(mgSlot1, nameId: 2488, parentGroupId: mgBoosters, groups: [mgBluePill]),
    _marketGroup(mgBluePill, nameId: 2491, parentGroupId: mgSlot1, types: [100, 101]),
    _marketGroup(mgSlot2, nameId: 2489, parentGroupId: mgBoosters, groups: [mgDrop]),
    _marketGroup(mgDrop, nameId: 2496, parentGroupId: mgSlot2, types: [200]),
    _marketGroup(mgAccelerators, nameId: 2487, parentGroupId: mgRoot, types: [400]),
  ];

  const names = {
    24: "Implants & Boosters",
    977: "Booster",
    2488: "Booster Slot 01",
    2491: "Blue Pill",
    2489: "Booster Slot 02",
    2496: "Drop",
    2487: "Cerebral Accelerators",
  };

  final baseTypes = {
    100: _type(100, marketGroupId: mgBluePill),
    101: _type(101, marketGroupId: mgBluePill),
    200: _type(200, marketGroupId: mgDrop),
    400: _type(400, marketGroupId: mgAccelerators),
  };

  final baseSlots = {
    100: Slots_BoosterSlot(typeId: 100, slotIndex: 1),
    101: Slots_BoosterSlot(typeId: 101, slotIndex: 1),
    200: Slots_BoosterSlot(typeId: 200, slotIndex: 2),
    400: Slots_BoosterSlot(typeId: 400, slotIndex: 10),
  };

  List<BoosterSlotSection> build({
    Map<int, Slots_BoosterSlot>? boosterSlots,
    Map<int, pb_types.Type>? types,
    List<pb_market.MarketGroup>? groups,
    int? slotFilter,
  }) => buildBoosterSlotSections(
    boosterSlots: boosterSlots ?? baseSlots,
    typeOf: (typeId) => (types ?? baseTypes)[typeId],
    marketGroups: groups ?? marketGroups,
    names: names,
    slotFallbackLabel: (slotIndex) => "Booster $slotIndex",
    otherLabel: "Other",
    slotFilter: slotFilter,
  );

  test("groups published booster types by slot with market labels", () {
    final sections = build();
    expect(sections.map((section) => section.slotIndex), [1, 2, 10]);

    final slot1 = sections[0];
    // The slot-level branch group wins over the leaf family group.
    expect(slot1.label, "Booster Slot 01");
    expect(slot1.families.single.label, "Blue Pill");
    expect(slot1.families.single.typeIds, [100, 101]);

    // The sibling "Cerebral Accelerators" group labels its own slot.
    final slot10 = sections[2];
    expect(slot10.label, "Cerebral Accelerators");
    expect(slot10.families.single.label, "Other");
    expect(slot10.families.single.typeIds, [400]);
  });

  test("excludes unpublished and unknown types", () {
    final sections = build(
      boosterSlots: {
        100: Slots_BoosterSlot(typeId: 100, slotIndex: 1),
        200: Slots_BoosterSlot(typeId: 200, slotIndex: 2),
        300: Slots_BoosterSlot(typeId: 300, slotIndex: 3),
      },
      types: {200: _type(200, published: false)},
    );

    expect(sections, isEmpty);
  });

  test("includes no-market-group published types in a trailing Other bucket", () {
    final sections = build(
      boosterSlots: {
        100: Slots_BoosterSlot(typeId: 100, slotIndex: 1),
        111: Slots_BoosterSlot(typeId: 111, slotIndex: 1),
      },
      types: {...baseTypes, 111: _type(111)},
    );

    final families = sections.single.families;
    expect(families.map((family) => family.label), ["Blue Pill", "Other"]);
    expect(families.last.typeIds, [111]);
  });

  test("falls back to a numeric slot label when no market group claims the slot", () {
    final sections = build(
      boosterSlots: {111: Slots_BoosterSlot(typeId: 111, slotIndex: 111)},
      types: {111: _type(111)},
    );

    final section = sections.single;
    expect(section.slotIndex, 111);
    expect(section.label, "Booster 111");
    expect(section.families.single.label, "Other");
  });

  test("orders sections by slot index", () {
    final sections = build(
      boosterSlots: {
        1: Slots_BoosterSlot(typeId: 1, slotIndex: 10),
        2: Slots_BoosterSlot(typeId: 2, slotIndex: 2),
        3: Slots_BoosterSlot(typeId: 3, slotIndex: 1),
      },
      types: {1: _type(1), 2: _type(2), 3: _type(3)},
    );

    expect(sections.map((section) => section.slotIndex), [1, 2, 10]);
  });

  test("slotFilter keeps only the requested slot", () {
    final sections = build(slotFilter: 2);

    expect(sections.map((section) => section.slotIndex), [2]);
    expect(sections.single.families.single.typeIds, [200]);
  });

  test("treats types attached to the section group itself as Other", () {
    // Serenity flattens some slot groups into leaf market groups with direct
    // types; those must not become a family duplicating the section label.
    final flatGroups = [
      _marketGroup(mgRoot, nameId: 24, groups: [mgBoosters]),
      _marketGroup(mgBoosters, nameId: 977, parentGroupId: mgRoot, groups: [mgSlot1, 2834]),
      _marketGroup(mgSlot1, nameId: 2488, parentGroupId: mgBoosters, types: [100]),
      _marketGroup(2834, nameId: 2834, parentGroupId: mgBoosters, types: [500]),
    ];
    final sections = build(
      boosterSlots: {
        100: Slots_BoosterSlot(typeId: 100, slotIndex: 1),
        500: Slots_BoosterSlot(typeId: 500, slotIndex: 89),
      },
      types: {
        100: _type(100, marketGroupId: mgSlot1),
        500: _type(500, marketGroupId: 2834),
      },
      groups: flatGroups,
    );

    final section = sections.firstWhere((section) => section.slotIndex == 89);
    // Name id 2834 is unresolved in [names]: the numeric fallback kicks in.
    expect(section.label, "Booster 89");
    expect(section.families.single.label, "Other");
  });

  test("slotFilter still derives section hierarchy from all published slots", () {
    // Same flattened fixture, but filtered to slot 89: without the unfiltered
    // hierarchy map, "Booster" would become the section and unresolved group
    // 2834 a blank family row instead of Other.
    final flatGroups = [
      _marketGroup(mgRoot, nameId: 24, groups: [mgBoosters]),
      _marketGroup(mgBoosters, nameId: 977, parentGroupId: mgRoot, groups: [mgSlot1, 2834]),
      _marketGroup(mgSlot1, nameId: 2488, parentGroupId: mgBoosters, types: [100]),
      _marketGroup(2834, nameId: 2834, parentGroupId: mgBoosters, types: [500]),
    ];
    final sections = build(
      boosterSlots: {
        100: Slots_BoosterSlot(typeId: 100, slotIndex: 1),
        500: Slots_BoosterSlot(typeId: 500, slotIndex: 89),
      },
      types: {
        100: _type(100, marketGroupId: mgSlot1),
        500: _type(500, marketGroupId: 2834),
      },
      groups: flatGroups,
      slotFilter: 89,
    );

    final section = sections.single;
    expect(section.slotIndex, 89);
    expect(section.label, "Booster 89");
    expect(section.families.single.label, "Other");
    expect(section.families.single.typeIds, [500]);
  });
}
