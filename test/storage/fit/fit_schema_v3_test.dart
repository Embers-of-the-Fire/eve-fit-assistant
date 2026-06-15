import "dart:convert";

import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";

FitStorage _makeFitStorage() => FitStorage(
  metadata: FitMetadata(
    fitId: "test-fit-1",
    shipTypeId: 1234,
    name: "Test Fit",
    lastModified: 0,
    description: "",
    checkoutRef: const CheckoutRef(checkoutId: "checkout-abc", serverId: "Serenity"),
  ),
  body: FitStorageBody(
    shipTypeId: 1234,
    characterId: "predefined_all_5",
    damageProfile: const FitDamageProfile(em: 0.25, explosive: 0.25, kinetic: 0.25, thermal: 0.25),
    slots: FitStorageSlots(
      high: const IList.empty(),
      medium: const IList.empty(),
      low: const IList.empty(),
      rig: const IList.empty(),
      subsystem: const IList.empty(),
      service: const IList.empty(),
      tacticalMode: const None(),
    ),
    drones: const IList.empty(),
    fighters: const IList.empty(),
    implants: const IList.empty(),
    boosters: const IList.empty(),
  ),
  dynamicRegistry: FitDynamicRegistry(dynamicItems: const IMap.empty()),
);

Map<String, dynamic> _roundTripJson(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  group("FitStorage v3 encoding", () {
    test("encodes with version 3 and checkoutRef", () {
      final fit = _makeFitStorage();
      final encoded = encodeFitStorage(fit);
      final json = _roundTripJson(encoded);

      expect(json["version"], 3);
      final fitPayload = json["fit"] as Map<String, dynamic>;
      final metadata = fitPayload["metadata"] as Map<String, dynamic>;
      final cr = metadata["checkoutRef"] as Map<String, dynamic>;
      expect(cr["checkoutId"], "checkout-abc");
      expect(cr["serverId"], "Serenity");
      expect(metadata.containsKey("bundleId"), isFalse);
      expect(metadata.containsKey("bundleSnapshot"), isFalse);
    });

    test("round-trips v3 fit storage through persistence", () {
      final fit = _makeFitStorage();
      final encoded = encodeFitStorage(fit);

      // Normalize through jsonEncode/jsonDecode to get pure Maps
      final normalized = _roundTripJson(encoded);
      final decoded = decodeFitStorage(normalized);

      expect(decoded.didMigrate, isFalse);
      expect(decoded.fit.metadata.fitId, "test-fit-1");
      expect(decoded.fit.metadata.checkoutRef.checkoutId, "checkout-abc");
      expect(decoded.fit.metadata.checkoutRef.serverId, "Serenity");
    });
  });

  group("FitStorage v2 is unsupported", () {
    test("decodeFitStorage throws on v2 payloads", () {
      final v2Json = <String, dynamic>{
        "version": 2,
        "fit": <String, dynamic>{
          "metadata": <String, dynamic>{
            "fitId": "test-fit-v2",
            "shipTypeId": 1234,
            "name": "V2 Fit",
            "lastModified": 100,
            "description": "",
            "bundleId": "Serenity-21.06-EQUINOX",
            "bundleSnapshot": "abc123",
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
              "high": <Map<String, dynamic>>[],
              "medium": <Map<String, dynamic>>[],
              "low": <Map<String, dynamic>>[],
              "rig": <Map<String, dynamic>>[],
              "subsystem": <Map<String, dynamic>>[],
              "service": <Map<String, dynamic>>[],
            },
            "drones": <Map<String, dynamic>>[],
            "fighters": <Map<String, dynamic>>[],
            "implants": <Map<String, dynamic>>[],
            "boosters": <Map<String, dynamic>>[],
          },
          "dynamicRegistry": <String, dynamic>{"dynamicItems": <String, dynamic>{}},
        },
      };

      expect(() => decodeFitStorage(v2Json), throwsA(isA<FitPersistenceException>()));
    });
  });
}
