import "dart:typed_data";

import "package:eve_fit_assistant/data/proto/categories.pb.dart" as pb_categories;
import "package:eve_fit_assistant/data/proto/collections.pb.dart";
import "package:eve_fit_assistant/data/proto/dogma_attributes.pb.dart" as pb_attrs;
import "package:eve_fit_assistant/data/proto/dogma_units.pb.dart" as pb_units;
import "package:eve_fit_assistant/data/proto/dynamic.pb.dart" as pb_dynamic;
import "package:eve_fit_assistant/data/proto/fit.pb.dart" as pb_fit;
import "package:eve_fit_assistant/data/proto/groups.pb.dart" as pb_groups;
import "package:eve_fit_assistant/data/proto/market_groups.pb.dart" as pb_market;
import "package:eve_fit_assistant/data/proto/meta_groups.pb.dart" as pb_meta;
import "package:eve_fit_assistant/data/proto/type_materials.pb.dart" as pb_materials;
import "package:eve_fit_assistant/data/proto/types.pb.dart" as pb_types;
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/collection_chunked_decode.dart";
import "package:flutter_test/flutter_test.dart";

Collection _testCollection() {
  final collection = Collection();
  collection.types.addAll({
    100: pb_types.Type(typeId: 100, groupId: 10, published: true),
    200: pb_types.Type(typeId: 200, groupId: 16, published: true),
    300: pb_types.Type(typeId: 300, groupId: 16, published: false),
  });
  collection.groups.addAll({
    10: pb_groups.Group(groupId: 10, categoryId: 6, published: true),
    16: pb_groups.Group(groupId: 16, categoryId: 16, published: true),
  });
  collection.categories.addAll({
    6: pb_categories.Category(categoryId: 6, published: true),
    16: pb_categories.Category(categoryId: 16, published: true),
  });
  collection.ships.addAll({
    100: pb_fit.Ship(typeId: 100, highSlots: 4, mediumSlots: 4, lowSlots: 4),
  });
  collection.marketGroups.addAll({5: pb_market.MarketGroup(marketGroupId: 5)});
  collection.metaGroups.addAll({3: pb_meta.MetaGroup(metaGroupId: 3)});
  collection.dogmaUnits.addAll({7: pb_units.DogmaUnit(dogmaUnitId: 7, name: "tf")});
  collection.dogmaAttributes.addAll({
    38: pb_attrs.DogmaAttribute(dogmaAttributeId: 38, name: "capacity"),
  });
  collection.subsystems.addAll({200: pb_fit.Subsystem(typeId: 200)});
  collection.typeMaterials.addAll({100: pb_materials.TypeMaterial(typeId: 100)});
  collection.dynamicMutators.addAll({
    900: pb_dynamic.DynamicMutator(modifierTypeId: 900, resultingTypeId: 901),
  });
  collection.dynamicTypeOptions.addAll({
    901: pb_dynamic.DynamicTypeOptions(modifierTypeIds: [900]),
  });
  collection.implantSets.addAll({
    1: pb_fit.ImplantSet(setId: 1, memberTypeIds: [700, 701]),
  });
  collection.skillProfiles.addAll({
    "alpha": Collection_SkillProfile(skills: [const MapEntry(200, 3)]),
  });
  collection.slots = pb_fit.Slots(highSlots: [
    MapEntry(0, pb_fit.Slots_HighSlot(typeId: 100, isTurret: true)),
  ]);
  return collection;
}

void main() {
  // Force a yield before every entry so the chunking path is exercised even
  // on tiny fixtures.
  const pace = ChunkedDecodeOptions(yieldEvery: Duration.zero);

  group("decodeCollectionChunked", () {
    test("matches Collection.fromBuffer", () async {
      final raw = Uint8List.fromList(_testCollection().writeToBuffer());

      final chunked = await decodeCollectionChunked(raw, pace);

      expect(chunked, equals(Collection.fromBuffer(raw)));
    });

    test("skips unknown top-level fields", () async {
      final known = Uint8List.fromList(_testCollection().writeToBuffer());
      // Prepend an unknown varint field (number 20): tag (20 << 3) | 0, value.
      final raw = Uint8List.fromList([0xA0, 0x01, 0x2A, ...known]);

      final chunked = await decodeCollectionChunked(raw, pace);

      expect(chunked, equals(Collection.fromBuffer(known)));
    });

    test("throws ChunkedDecodeCancelled when cancelled", () async {
      final raw = Uint8List.fromList(_testCollection().writeToBuffer());
      var calls = 0;

      await expectLater(
        decodeCollectionChunked(
          raw,
          ChunkedDecodeOptions(
            yieldEvery: Duration.zero,
            isCancelled: () => ++calls > 1,
          ),
        ),
        throwsA(isA<ChunkedDecodeCancelled>()),
      );
    });
  });

  group("RepoCollectionService.decodeFromBytesChunked", () {
    test("exposes the same query surface as decodeFromBytes", () async {
      final collectionBytes = Uint8List.fromList(_testCollection().writeToBuffer());

      final reference = RepoCollectionService.decodeFromBytes(collectionBytes: collectionBytes);
      final chunked = await RepoCollectionService.decodeFromBytesChunked(
        collectionBytes: collectionBytes,
        isCancelled: () => false,
      );

      expect(chunked.getShip(100), equals(reference.getShip(100)));
      expect(chunked.getType(200), equals(reference.getType(200)));
      expect(chunked.getGroup(16), equals(reference.getGroup(16)));
      expect(chunked.getCategory(6), equals(reference.getCategory(6)));
      expect(chunked.getMarketGroup(5), equals(reference.getMarketGroup(5)));
      expect(chunked.getMetaGroup(3), equals(reference.getMetaGroup(3)));
      expect(chunked.getDogmaUnit(7), equals(reference.getDogmaUnit(7)));
      expect(chunked.getDogmaAttribute(38), equals(reference.getDogmaAttribute(38)));
      expect(chunked.getSubsystem(200), equals(reference.getSubsystem(200)));
      expect(chunked.getTypeMaterial(100), equals(reference.getTypeMaterial(100)));
      expect(chunked.getDynamicMutator(900), equals(reference.getDynamicMutator(900)));
      expect(
        chunked.getDynamicTypeOptions(901),
        equals(reference.getDynamicTypeOptions(901)),
      );
      expect(chunked.getImplantSet(1), equals(reference.getImplantSet(1)));
      expect(chunked.getImplantSetForType(701), equals(reference.getImplantSetForType(701)));
      expect(chunked.getSkillProfile("alpha"), equals(reference.getSkillProfile("alpha")));
      expect(chunked.getSkillTypeIds(), equals(reference.getSkillTypeIds()));
      expect(chunked.slots, equals(reference.slots));
    });
  });
}
