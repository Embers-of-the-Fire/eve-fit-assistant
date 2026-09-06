import "dart:typed_data";

import "package:efa_proto/collections.pb.dart";
import "package:efa_proto/dynamic.pb.dart" as pb_dynamic;
import "package:efa_proto/types.pb.dart" as pb_types;
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("dynamic drone data gating", () {
    test("mutator-less collection hides drone mutation", () {
      // Simulates an old data bundle: no dynamic mutators at all. The UI keys
      // Convert/Mutate actions off these lookups, so the feature stays hidden.
      final collection = RepoCollectionService.decodeFromBytes(
        collectionBytes: Uint8List.fromList(Collection().writeToBuffer()),
      );

      expect(collection.getDynamicTypeOptions(2203), isNull);
      expect(collection.getDynamicMutator(60460), isNull);
    });

    test("collection with drone mutators exposes options for applicable drones", () {
      final raw = Collection()
        ..types.addAll({
          2203: pb_types.Type(typeId: 2203, groupId: 100, published: true),
        })
        ..dynamicMutators.addAll({
          60460: pb_dynamic.DynamicMutator(
            modifierTypeId: 60460,
            resultingTypeId: 60478,
            applicableTypes: [2203],
          ),
        })
        ..dynamicTypeOptions.addAll({
          2203: pb_dynamic.DynamicTypeOptions(modifierTypeIds: [60460]),
        });
      final collection = RepoCollectionService.decodeFromBytes(
        collectionBytes: Uint8List.fromList(raw.writeToBuffer()),
      );

      expect(collection.getDynamicTypeOptions(2203)?.modifierTypeIds, [60460]);
      expect(collection.getDynamicMutator(60460)?.resultingTypeId, 60478);
      expect(collection.getDynamicMutator(60460)?.applicableTypes, contains(2203));
    });
  });
}
