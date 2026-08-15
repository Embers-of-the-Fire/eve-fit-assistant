import "dart:convert";

import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";

FitStorage _makeFitStorage() => const FitStorage(
  metadata: FitMetadata(
    fitId: "test-fit-1",
    shipTypeId: 12017,
    name: "Test Fit",
    lastModified: 0,
    description: "",
    checkoutRef: CheckoutRef(checkoutId: "checkout-abc", serverId: "Serenity"),
  ),
  body: FitStorageBody(
    shipTypeId: 12017,
    characterId: "predefined_all_5",
    damageProfile: FitDamageProfile(em: 0.25, explosive: 0.25, kinetic: 0.25, thermal: 0.25),
    slots: FitStorageSlots(
      high: IList.empty(),
      medium: IList.empty(),
      low: IList.empty(),
      rig: IList.empty(),
      subsystem: IList.empty(),
      service: IList.empty(),
      tacticalMode: None(),
    ),
    drones: IList.empty(),
    fighters: IList.empty(),
    implants: IList.empty(),
    boosters: IList.empty(),
  ),
  dynamicRegistry: FitDynamicRegistry(dynamicItems: IMap.empty()),
);

Map<String, dynamic> _legacyV1FitJson() => <String, dynamic>{
  "metadata": <String, dynamic>{
    "fitId": "b7277b87-c880-4a5e-b474-7b59728d1f18",
    "shipTypeId": 12017,
    "name": "500推",
    "lastModified": 1784685359885,
    "description": "",
    "bundleId": "tranquility",
    "bundleSnapshot": <String, dynamic>{
      "bundleId": "tranquility",
      "manifestHash": "fe5818576d58985e7aff57997c1736239974253b8d7055ce1707be75312d2227",
      "gameBuild": "3409592",
      "appVersion": "0.1.0-beta.6+6",
      "generateTimestamp": 1782620853,
    },
  },
  "body": <String, dynamic>{
    "shipTypeId": 12017,
    "characterId": "predefined_all_5",
    "damageProfile": <String, dynamic>{
      "em": 0.25,
      "explosive": 0.25,
      "kinetic": 0.25,
      "thermal": 0.25,
    },
    "slots": <String, dynamic>{
      "high": <dynamic>[
        <String, dynamic>{
          "itemId": <String, dynamic>{"id": 4248, "runtimeType": "item"},
          "state": "active",
          "charge": null,
        },
        null,
      ],
      "medium": <dynamic>[],
      "low": <dynamic>[],
      "rig": <dynamic>[],
      "subsystem": <dynamic>[null, null, null, null],
      "service": <dynamic>[],
      "tacticalMode": null,
    },
    "drones": <dynamic>[],
    "fighters": <dynamic>[],
    "implants": <dynamic>[],
    "boosters": <dynamic>[],
  },
  "dynamicRegistry": <String, dynamic>{"dynamicItems": <String, dynamic>{}},
};

Map<String, dynamic> _roundTripJson(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  group("encodeNativeFitPayload", () {
    test("emits version 2 envelope wrapping the fit storage envelope", () {
      final encoded = _roundTripJson(encodeNativeFitPayload(_makeFitStorage()));

      expect(encoded["version"], 2);
      final inner = encoded["fit"] as Map<String, dynamic>;
      expect(inner["version"], 2);
      expect(inner["fit"], isA<Map<String, dynamic>>());
    });
  });

  group("decodeNativeFitPayload", () {
    test("round-trips current v2 payloads without migration", () {
      final fit = _makeFitStorage();
      final decoded = decodeNativeFitPayload(_roundTripJson(encodeNativeFitPayload(fit)));

      expect(decoded.didMigrate, isFalse);
      expect(decoded.fit.metadata.fitId, "test-fit-1");
      expect(decoded.fit.metadata.checkoutRef.checkoutId, "checkout-abc");
      expect(decoded.fit.body.shipTypeId, 12017);
    });

    test("migrates legacy v1 payloads with object bundleSnapshot", () {
      final payload = <String, dynamic>{"version": 1, "fit": _legacyV1FitJson()};

      final decoded = decodeNativeFitPayload(_roundTripJson(payload));

      expect(decoded.didMigrate, isTrue);
      expect(decoded.fit.metadata.fitId, "b7277b87-c880-4a5e-b474-7b59728d1f18");
      expect(decoded.fit.metadata.name, "500推");
      expect(decoded.fit.metadata.checkoutRef.checkoutId, "");
      expect(decoded.fit.metadata.checkoutRef.serverId, "");
      expect(decoded.fit.body.shipTypeId, 12017);
      expect(decoded.fit.body.slots.high.length, 2);
      expect(decoded.fit.body.slots.subsystem.length, 4);
    });

    test("migrates legacy v1 payloads with string bundleSnapshot", () {
      final fitJson = _legacyV1FitJson();
      final metadata = fitJson["metadata"]! as Map<String, dynamic>;
      metadata["bundleId"] = "Tranquility-21.06-3409592";
      metadata["bundleSnapshot"] = "checkout-legacy";

      final payload = <String, dynamic>{"version": 1, "fit": fitJson};
      final decoded = decodeNativeFitPayload(_roundTripJson(payload));

      expect(decoded.didMigrate, isTrue);
      expect(decoded.fit.metadata.checkoutRef.checkoutId, "checkout-legacy");
      expect(decoded.fit.metadata.checkoutRef.serverId, "Tranquility");
    });

    test("keeps existing checkoutRef when migrating legacy v1 payloads", () {
      final fitJson = _legacyV1FitJson();
      final metadata = fitJson["metadata"]! as Map<String, dynamic>;
      metadata["checkoutRef"] = <String, dynamic>{
        "checkoutId": "checkout-keep",
        "serverId": "Serenity",
      };

      final payload = <String, dynamic>{"version": 1, "fit": fitJson};
      final decoded = decodeNativeFitPayload(_roundTripJson(payload));

      expect(decoded.fit.metadata.checkoutRef.checkoutId, "checkout-keep");
    });

    test("throws unsupportedVersion for newer payload versions", () {
      final payload = <String, dynamic>{"version": 99, "fit": <String, dynamic>{}};

      expect(
        () => decodeNativeFitPayload(payload),
        throwsA(
          isA<FitPersistenceException>().having(
            (error) => error.code,
            "code",
            FitPersistenceErrorCode.unsupportedVersion,
          ),
        ),
      );
    });

    test("throws invalidPayloadShape when version is missing", () {
      final payload = <String, dynamic>{"fit": _legacyV1FitJson()};

      expect(
        () => decodeNativeFitPayload(payload),
        throwsA(
          isA<FitPersistenceException>().having(
            (error) => error.code,
            "code",
            FitPersistenceErrorCode.invalidPayloadShape,
          ),
        ),
      );
    });
  });
}
