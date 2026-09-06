import "dart:convert";

import "package:eve_fit_assistant/native/api/storage.dart" as native;
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:flutter_test/flutter_test.dart";

/// Hand-written v2 fit payload with one drone stack whose `itemId` is a
/// dynamic reference (origin 2203 Hobgoblin I, mutated 60478 "Light Mutated
/// Drone", mutator 60460 "Exigent Light Drone Navigation Mutaplasmid").
///
/// All factors lie inside the mutator's `[min, max]` ranges as shipped in the
/// current data bundle. This fixture represents a payload produced by a future
/// app version and must be handled gracefully by the current code.
Map<String, dynamic> _dynamicDroneV2FitJson() => <String, dynamic>{
  "version": 2,
  "fit": <String, dynamic>{
    "metadata": <String, dynamic>{
      "fitId": "test-fit-dynamic-drone",
      "shipTypeId": 1234,
      "name": "Dynamic Drone Fit",
      "lastModified": 0,
      "description": "",
      "checkoutRef": <String, dynamic>{"checkoutId": "checkout-abc", "serverId": "Serenity"},
    },
    "body": <String, dynamic>{
      "shipTypeId": 1234,
      "characterId": "predefined_all_5",
      "damageProfile": <String, dynamic>{
        "em": 0.25,
        "explosive": 0.25,
        "kinetic": 0.25,
        "thermal": 0.25,
      },
      "slots": <String, dynamic>{
        "high": <dynamic>[],
        "medium": <dynamic>[],
        "low": <dynamic>[],
        "rig": <dynamic>[],
        "subsystem": <dynamic>[],
        "service": <dynamic>[],
        "tacticalMode": null,
      },
      "drones": <dynamic>[
        <String, dynamic>{
          "itemId": <String, dynamic>{"dynamicId": 0, "runtimeType": "dynamic"},
          "state": "active",
          "quantity": 5,
        },
      ],
      "fighters": <dynamic>[],
      "implants": <dynamic>[],
      "boosters": <dynamic>[],
    },
    "dynamicRegistry": <String, dynamic>{
      "dynamicItems": <String, dynamic>{
        "0": <String, dynamic>{
          "dynamicItemId": 0,
          "originTypeId": 2203,
          "typeId": 60478,
          "modifierTypeId": 60460,
          "dynamicAttributes": <String, dynamic>{
            "9": 1.05,
            "37": 1.15,
            "54": 0.95,
            "64": 1.05,
            "158": 0.9,
            "160": 1.2,
            "263": 1.1,
            "265": 0.8,
          },
        },
      },
    },
  },
};

Map<String, dynamic> _roundTripJson(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  group("dynamic drone forward compatibility (v2 fixture)", () {
    test("decodes a dynamic drone stack without migration", () {
      final decoded = decodeFitStorage(_roundTripJson(_dynamicDroneV2FitJson()));

      expect(decoded.didMigrate, isFalse);
      final drone = decoded.fit.body.drones.single;
      expect(drone.itemId.dynamicIdOrNull, 0);
      expect(drone.quantity, 5);
      final dynamicItem = decoded.fit.dynamicRegistry.dynamicItems[0];
      expect(dynamicItem, isNotNull);
      expect(dynamicItem!.originTypeId, 2203);
      expect(dynamicItem.typeId, 60478);
      expect(dynamicItem.modifierTypeId, 60460);
    });

    test("convertFitBodyToNative passes dynamic drone item ids through", () {
      final fit = decodeFitStorage(_roundTripJson(_dynamicDroneV2FitJson())).fit;

      final nativeFit = convertFitBodyToNative(fit);

      expect(nativeFit.drones, hasLength(5));
      for (final drone in nativeFit.drones) {
        expect(drone.itemId, isA<native.ItemID_Dynamic>());
        expect((drone.itemId as native.ItemID_Dynamic).field0, 0);
        expect(drone.groupId, 0);
        expect(drone.state, native.State.active);
      }
    });

    test("load-prune-save preserves the dynamic registry entry", () {
      final fit = decodeFitStorage(_roundTripJson(_dynamicDroneV2FitJson())).fit;

      final pruned = pruneDynamicRegistry(fit);

      expect(pruned.dynamicRegistry.dynamicItems.keys, contains(0));
      expect(
        pruned.dynamicRegistry.dynamicItems[0]!.dynamicAttributes[64],
        fit.dynamicRegistry.dynamicItems[0]!.dynamicAttributes[64],
      );

      final reDecoded = decodeFitStorage(_roundTripJson(encodeFitStorage(pruned)));
      expect(reDecoded.didMigrate, isFalse);
      expect(reDecoded.fit.dynamicRegistry.dynamicItems.keys, contains(0));
      expect(reDecoded.fit.body.drones.single.itemId.dynamicIdOrNull, 0);
    });
  });
}
