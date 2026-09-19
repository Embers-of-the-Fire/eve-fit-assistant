import "dart:convert";

import "package:eve_fit_assistant/native/api/storage.dart" as native;
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";

FitStorage _makeFitStorage(IList<FitSystemBuff> systemBuffs) => FitStorage(
  metadata: const FitMetadata(
    fitId: "test-fit-system-buffs",
    shipTypeId: 1234,
    name: "System Buff Fit",
    lastModified: 0,
    description: "",
    checkoutRef: CheckoutRef(checkoutId: "checkout-abc", serverId: "Serenity"),
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
    systemBuffs: systemBuffs,
  ),
  dynamicRegistry: FitDynamicRegistry(dynamicItems: const IMap.empty()),
);

Map<String, dynamic> _roundTripJson(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  group("FitStorage systemBuffs", () {
    test("defaults to an empty list when the field is absent", () {
      final fit = _makeFitStorage(const IList.empty());
      final json = _roundTripJson(encodeFitStorage(fit));
      ((json["fit"] as Map<String, dynamic>)["body"] as Map<String, dynamic>)
          .remove("systemBuffs");

      final decoded = decodeFitStorage(json);

      expect(decoded.fit.body.systemBuffs, isEmpty);
    });

    test("round-trips preset and custom entries", () {
      final fit = _makeFitStorage(
        IList(const [
          FitSystemBuff(buffId: -2001, value: 2.0, presetId: "wormhole.pulsar.6"),
          FitSystemBuff(buffId: -2003, value: 50.0, presetId: "wormhole.pulsar.6"),
          FitSystemBuff(buffId: 92, value: -50.0),
        ]),
      );

      final decoded = decodeFitStorage(_roundTripJson(encodeFitStorage(fit)));

      expect(decoded.didMigrate, isFalse);
      final buffs = decoded.fit.body.systemBuffs;
      expect(buffs, hasLength(3));
      expect(buffs[0].buffId, -2001);
      expect(buffs[0].value, 2.0);
      expect(buffs[0].presetId, "wormhole.pulsar.6");
      expect(buffs[2].buffId, 92);
      expect(buffs[2].value, -50.0);
      expect(buffs[2].presetId, isNull);
    });

    test("convertFitBodyToNative maps entries to native system buffs", () {
      final fit = _makeFitStorage(
        IList(const [
          FitSystemBuff(buffId: -2021, value: 2.0, presetId: "wormhole.magnetar.6"),
          FitSystemBuff(buffId: 92, value: -50.0),
        ]),
      );

      final nativeFit = convertFitBodyToNative(fit);

      expect(nativeFit.systemBuffs, hasLength(2));
      expect(nativeFit.systemBuffs[0].buffId, -2021);
      expect(nativeFit.systemBuffs[0].value, 2.0);
      expect(nativeFit.systemBuffs[1].buffId, 92);
      expect(nativeFit.systemBuffs[1].value, -50.0);
    });

    test("native fit type exposes system buffs for the engine bridge", () {
      final fit = native.Fit(
        shipTypeId: 1234,
        damageProfile: native.DamageProfile(em: 0.25, explosive: 0.25, kinetic: 0.25, thermal: 0.25),
        modules: const [],
        drones: const [],
        fighters: const [],
        implants: const [],
        boosters: const [],
        systemBuffs: const [native.SystemBuff(buffId: -2001, value: 2.0)],
      );

      expect(fit.systemBuffs.single.buffId, -2001);
      expect(fit.systemBuffs.single.value, 2.0);
    });
  });
}
