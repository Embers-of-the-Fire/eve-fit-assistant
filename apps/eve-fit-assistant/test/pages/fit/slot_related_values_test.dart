import "dart:typed_data";

import "package:eve_fit_assistant/constant/eve.dart";
import "package:eve_fit_assistant/native/api/output.dart" as native;
import "package:eve_fit_assistant/native/api/storage.dart" as native_storage;
import "package:eve_fit_assistant/pages/fit/components/equipment/slot_row/related_values_logic.dart";
import "package:flutter_test/flutter_test.dart";

native.Item buildItem({Map<int, double> attributes = const {}, native.Item? charge}) => native.Item(
  itemId: const native_storage.ItemID.item(0),
  slot: const native.OutSlot(slotType: native.OutSlotType.high(), index: 0),
  charge: charge,
  state: native.EffectCategory.active,
  attributes: {
    for (final entry in attributes.entries)
      entry.key: native.Attribute(
        baseValue: entry.value,
        value: entry.value,
        buffs: Int32List(0),
        trackedModifiers: const [],
      ),
  },
  effects: Int32List(0),
);

void main() {
  group("collectSlotRelatedValues", () {
    group("turret range", () {
      test("optimal only", () {
        final segments = collectSlotRelatedValues(
          buildItem(attributes: {EveConstAttrID.maxRange: 54000}),
        );
        expect(segments, hasLength(1));
        expect(segments.single.iconAttributeId, EveConstAttrID.maxRange);
        expect(segments.single.text, "54.0 km");
      });

      test("optimal with falloff", () {
        final segments = collectSlotRelatedValues(
          buildItem(attributes: {EveConstAttrID.maxRange: 54000, EveConstAttrID.falloff: 12000}),
        );
        expect(segments.single.text, "54.0 km + 12.0 km");
      });

      test("optimal with falloff and falloff effectiveness", () {
        final segments = collectSlotRelatedValues(
          buildItem(
            attributes: {
              EveConstAttrID.maxRange: 54000,
              EveConstAttrID.falloff: 12000,
              EveConstAttrID.falloffEffectiveness: 6000,
            },
          ),
        );
        expect(segments.single.text, "54.0 km + 12.0 km + 6.0 km");
      });

      test("zero falloff is omitted", () {
        final segments = collectSlotRelatedValues(
          buildItem(
            attributes: {
              EveConstAttrID.maxRange: 54000,
              EveConstAttrID.falloff: 0,
              EveConstAttrID.falloffEffectiveness: 0,
            },
          ),
        );
        expect(segments.single.text, "54.0 km");
      });

      test("optimal range takes priority over EMP field range", () {
        final segments = collectSlotRelatedValues(
          buildItem(
            attributes: {EveConstAttrID.maxRange: 54000, EveConstAttrID.empFieldRange: 20000},
          ),
        );
        expect(segments.single.text, "54.0 km");
      });
    });

    group("missile range", () {
      test("derived from charge velocity and flight time", () {
        final segments = collectSlotRelatedValues(
          buildItem(
            charge: buildItem(
              attributes: {EveConstAttrID.maxVelocity: 5000, EveConstAttrID.explosionDelay: 4000},
            ),
          ),
        );
        expect(segments, hasLength(1));
        expect(segments.single.iconAttributeId, EveConstAttrID.maxRange);
        expect(segments.single.text, "20.0 km");
      });

      test("zero when charge has no flight attributes", () {
        final segments = collectSlotRelatedValues(buildItem(charge: buildItem()));
        expect(segments, isEmpty);
      });

      test("zero velocity yields no range segment", () {
        final segments = collectSlotRelatedValues(
          buildItem(
            charge: buildItem(
              attributes: {EveConstAttrID.maxVelocity: 0, EveConstAttrID.explosionDelay: 4000},
            ),
          ),
        );
        expect(segments, isEmpty);
      });
    });

    group("EMP field range fallback", () {
      test("used when no optimal range and no charge", () {
        final segments = collectSlotRelatedValues(
          buildItem(attributes: {EveConstAttrID.empFieldRange: 20000}),
        );
        expect(segments, hasLength(1));
        expect(segments.single.iconAttributeId, EveConstAttrID.maxRange);
        expect(segments.single.text, "20.0 km");
      });

      test("zero field range yields no segment", () {
        final segments = collectSlotRelatedValues(
          buildItem(attributes: {EveConstAttrID.empFieldRange: 0}),
        );
        expect(segments, isEmpty);
      });
    });

    group("capacitor usage", () {
      test("capacitor need per cycle time", () {
        final segments = collectSlotRelatedValues(
          buildItem(
            attributes: {EveConstAttrID.capacitorNeed: 30, EveConstExtendedAttrID.cycleTime: 5000},
          ),
        );
        expect(segments, hasLength(1));
        expect(segments.single.iconAttributeId, EveConstAttrID.capacitorNeed);
        expect(segments.single.text, "6.0 GJ/s");
      });

      test("omitted when cycle time is zero", () {
        final segments = collectSlotRelatedValues(
          buildItem(
            attributes: {EveConstAttrID.capacitorNeed: 30, EveConstExtendedAttrID.cycleTime: 0},
          ),
        );
        expect(segments, isEmpty);
      });

      test("omitted when capacitor need is zero", () {
        final segments = collectSlotRelatedValues(
          buildItem(
            attributes: {EveConstAttrID.capacitorNeed: 0, EveConstExtendedAttrID.cycleTime: 5000},
          ),
        );
        expect(segments, isEmpty);
      });

      test("omitted when below display threshold", () {
        final segments = collectSlotRelatedValues(
          buildItem(
            attributes: {
              EveConstAttrID.capacitorNeed: 0.001,
              EveConstExtendedAttrID.cycleTime: 1000,
            },
          ),
        );
        expect(segments, isEmpty);
      });
    });

    test("item without attributes yields no segments", () {
      expect(collectSlotRelatedValues(buildItem()), isEmpty);
    });

    test("range and capacitor segments combine", () {
      final segments = collectSlotRelatedValues(
        buildItem(
          attributes: {
            EveConstAttrID.maxRange: 54000,
            EveConstAttrID.capacitorNeed: 30,
            EveConstExtendedAttrID.cycleTime: 5000,
          },
        ),
      );
      expect(segments, hasLength(2));
      expect(segments[0].text, "54.0 km");
      expect(segments[1].text, "6.0 GJ/s");
    });
  });
}
