import "package:eve_fit_assistant/pages/fit/components/system_effect/system_effect_catalog.dart";
import "package:eve_fit_assistant/pages/fit/components/system_effect/system_effect_resolver.dart";
import "package:flutter_test/flutter_test.dart";

/// Beacon dogma fixtures mirroring the tranquility snapshot values
/// (data/resources/*/fsd/typedogma.msgpack).
final _beaconDogma = <int, Map<int, double>>{
  // Pulsar class 1 / class 6 (wormhole attr mapping).
  30844: {146: 1.3, 652: 1.3, 1465: 15, 1466: 15, 1467: 15, 1468: 15, 1500: 0.85, 1966: 1.3},
  30869: {146: 2.0, 652: 2.0, 1465: 50, 1466: 50, 1467: 50, 1468: 50, 1500: 0.5, 1966: 2.0},
  // Red Giant class 1 (two buffs share beacon attribute 1488).
  30848: {1485: 1.15, 1486: 1.3, 1487: 1.3, 1488: 1.3},
  // Electrical storm strong / weak (storm attr mapping).
  56057: {984: 25, 1465: 25, 1489: 25, 1500: 0.75, 1915: 25, 2454: 1, 3095: 50},
  56064: {984: 10, 1465: 10, 1489: 10, 1500: 0.9, 1915: 10, 2454: 1, 3095: 20},
  // Electrical weather tiers 1-3 (warfareBuff pairs).
  47381: {2468: 90, 2469: 30, 2470: 92, 2471: -50},
  47383: {2468: 90, 2469: 70, 2470: 92, 2471: -50},
  // Caustic hazard cloud.
  47436: {2468: 80, 2469: -50, 2470: 81, 2471: 300},
};

Map<int, double>? _attrsOf(int typeId) => _beaconDogma[typeId];

void main() {
  group("resolvePresetBuffs", () {
    test("wormhole preset resolves values from the beacon attr mapping", () {
      final preset = systemEffectPresetById["wormhole.pulsar.1"]!;
      final buffs = resolvePresetBuffs(preset, _attrsOf);

      expect(buffs, isNotNull);
      final byId = {for (final b in buffs!) b.buffId: b.value};
      expect(byId, {
        -2001: 1.3, // shield HP
        -2002: 1.3, // signature radius
        -2003: 15.0, // armor resistance
        -2004: 0.85, // capacitor recharge
        -2005: 1.3, // energy warfare
      });
      expect(buffs.every((b) => b.presetId == "wormhole.pulsar.1"), isTrue);
    });

    test("wormhole class 6 preset reads the class 6 beacon", () {
      final preset = systemEffectPresetById["wormhole.pulsar.6"]!;
      final byId = {for (final b in resolvePresetBuffs(preset, _attrsOf)!) b.buffId: b.value};
      expect(byId[-2001], 2.0);
      expect(byId[-2003], 50.0);
      expect(byId[-2004], 0.5);
    });

    test("two buffs sharing one beacon attribute both resolve (Red Giant)", () {
      final preset = systemEffectPresetById["wormhole.red_giant.1"]!;
      final byId = {for (final b in resolvePresetBuffs(preset, _attrsOf)!) b.buffId: b.value};
      expect(byId[-2027], 1.3); // smart bomb damage
      expect(byId[-2028], 1.3); // bomb damage
    });

    test("storm presets resolve per-strength values", () {
      final strong = systemEffectPresetById["storm.electrical.strong"]!;
      final weak = systemEffectPresetById["storm.electrical.weak"]!;

      final strongById = {for (final b in resolvePresetBuffs(strong, _attrsOf)!) b.buffId: b.value};
      expect(strongById, {-2101: 25.0, -2102: 0.75});

      final weakById = {for (final b in resolvePresetBuffs(weak, _attrsOf)!) b.buffId: b.value};
      expect(weakById, {-2101: 10.0, -2102: 0.9});
    });

    test("warfare preset expands the beacon's warfareBuff pairs", () {
      final tier1 = systemEffectPresetById["weather.electrical.1"]!;
      final buffs = resolvePresetBuffs(tier1, _attrsOf)!;
      final byId = {for (final b in buffs) b.buffId: b.value};
      expect(byId, {90: 30.0, 92: -50.0});
      expect(buffs.every((b) => b.presetId == "weather.electrical.1"), isTrue);

      final tier3 = systemEffectPresetById["weather.electrical.3"]!;
      final byId3 = {for (final b in resolvePresetBuffs(tier3, _attrsOf)!) b.buffId: b.value};
      expect(byId3, {90: 70.0, 92: -50.0});
    });

    test("hazard preset expands warfare pairs", () {
      final preset = systemEffectPresetById["hazard.caustic"]!;
      final byId = {for (final b in resolvePresetBuffs(preset, _attrsOf)!) b.buffId: b.value};
      expect(byId, {80: -50.0, 81: 300.0});
    });

    test("static presets return their pre-expanded entries untouched", () {
      final preset = systemEffectPresetById["sov.gamma"]!;
      final buffs = resolvePresetBuffs(preset, _attrsOf)!;
      final byId = {for (final b in buffs) b.buffId: b.value};
      expect(byId, {2433: 5.0, 2434: 10.0, 2441: 5.0});
      expect(buffs.every((b) => b.presetId == "sov.gamma"), isTrue);
    });

    test("static presets resolve without any beacon data", () {
      final preset = systemEffectPresetById["trig.pochven"]!;
      expect(resolvePresetBuffs(preset, (_) => null), isNotNull);
    });

    test("absent beacon resolves to null", () {
      final preset = systemEffectPresetById["wormhole.pulsar.1"]!;
      expect(resolvePresetBuffs(preset, (_) => null), isNull);
    });

    test("beacon with unusable dogma resolves to null", () {
      final preset = systemEffectPresetById["weather.electrical.1"]!;
      expect(resolvePresetBuffs(preset, (_) => {}), isNull);
      expect(resolvePresetBuffs(preset, (_) => {2468: 0, 2469: 30}), isNull);
    });

    test("every fixture-backed preset resolves against the fixture dogma", () {
      var covered = 0;
      for (final preset in systemEffectCatalog) {
        final beacon = preset.beaconTypeId;
        if (beacon == null || !_beaconDogma.containsKey(beacon)) continue;
        covered++;
        final buffs = resolvePresetBuffs(preset, _attrsOf);
        expect(buffs, isNotNull, reason: "preset ${preset.id} (beacon $beacon) should resolve");
      }
      expect(covered, 8, reason: "fixture should cover all resolution modes");
    });
  });

  group("resolveLibraryDefaultValue", () {
    test("authored buffs default to the weakest class/strength beacon value", () {
      final pulsarShield = systemBuffLibraryById[-2001]!;
      expect(resolveLibraryDefaultValue(pulsarShield, _attrsOf), 1.3);

      final stormEmRes = systemBuffLibraryById[-2101]!;
      expect(resolveLibraryDefaultValue(stormEmRes, _attrsOf), 10.0);
    });

    test("native warfare buffs default to the tier-1 beacon pair value", () {
      expect(resolveLibraryDefaultValue(systemBuffLibraryById[90]!, _attrsOf), 30.0);
      expect(resolveLibraryDefaultValue(systemBuffLibraryById[92]!, _attrsOf), -50.0);
      expect(resolveLibraryDefaultValue(systemBuffLibraryById[80]!, _attrsOf), -50.0);
      expect(resolveLibraryDefaultValue(systemBuffLibraryById[81]!, _attrsOf), 300.0);
    });

    test("static-fallback buffs default to 1.0", () {
      expect(resolveLibraryDefaultValue(systemBuffLibraryById[2433]!, _attrsOf), 1.0);
      expect(resolveLibraryDefaultValue(systemBuffLibraryById[2405]!, _attrsOf), 1.0);
    });

    test("beacon-backed entries fall back gracefully when the beacon is absent", () {
      expect(resolveLibraryDefaultValue(systemBuffLibraryById[-2001]!, (_) => null), 1.0);
      expect(resolveLibraryDefaultValue(systemBuffLibraryById[90]!, (_) => null), 1.0);
    });
  });
}
