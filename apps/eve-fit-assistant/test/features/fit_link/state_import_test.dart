@TestOn("vm")
library;

import "package:efa_proto/fit.pb.dart";
import "package:efa_proto/fit_request.pb.dart" hide FitDynamicItem;
import "package:efa_proto/fit_request.pb.dart"
    as fit_request
    show FitDynamicAttribute, FitDynamicItem;
import "package:efa_proto/fit_snapshot.pb.dart";
import "package:eve_fit_assistant/features/fit_link/state_import.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:flutter_test/flutter_test.dart";

SnapshotShipLayout _layout({
  int high = 2,
  int medium = 0,
  int low = 0,
  int rig = 0,
  int subsystem = 0,
  int service = 0,
}) => SnapshotShipLayout(
  highSlots: high,
  mediumSlots: medium,
  lowSlots: low,
  rigSlots: rig,
  subsystemSlots: subsystem,
  serviceSlots: service,
  turretHardpoints: 0,
  launcherHardpoints: 0,
  fighterTubes: 0,
);

DamageProfile _profile() => DamageProfile(em: 0.1, thermal: 0.2, kinetic: 0.3, explosive: 0.4);

void main() {
  group("fitStateToStorage", () {
    test("maps the header fields and damage profile", () {
      final converted = fitStateToStorage(
        FitState(shipTypeId: 12017, layout: _layout(), damageProfile: _profile()),
        characterId: "predefined_all_5",
      );

      expect(converted.body.shipTypeId, 12017);
      expect(converted.body.characterId, "predefined_all_5");
      expect(converted.body.damageProfile.em, 0.1);
      expect(converted.body.damageProfile.thermal, 0.2);
      expect(converted.body.damageProfile.kinetic, 0.3);
      expect(converted.body.damageProfile.explosive, 0.4);
      expect(converted.dynamicRegistry.dynamicItems, isEmpty);
    });

    test("places modules by rack and index, honoring the layout size", () {
      final converted = fitStateToStorage(
        FitState(
          shipTypeId: 12017,
          layout: _layout(high: 3, rig: 2),
          damageProfile: _profile(),
          modules: [
            FitModule(
              typeId: 12001,
              slotType: SlotType.HIGH,
              index: 1,
              state: Slots_SlotState.ACTIVE,
              chargeTypeId: 200,
            ),
            FitModule(
              typeId: 12002,
              slotType: SlotType.RIG,
              index: 0,
              state: Slots_SlotState.ONLINE,
            ),
          ],
        ),
        characterId: "predefined_all_5",
      );

      final high = converted.body.slots.high;
      expect(high, hasLength(3));
      expect(high[0].isNone(), isTrue);
      final module = high[1].toNullable();
      expect(module?.itemId, const FitStorageItemId.item(id: 12001));
      expect(module?.state, FitItemState.active);
      expect(module?.charge.toNullable()?.typeId, 200);
      expect(high[2].isNone(), isTrue);

      final rig = converted.body.slots.rig;
      expect(rig, hasLength(2));
      expect(rig[0].toNullable()?.itemId, const FitStorageItemId.item(id: 12002));
      expect(rig[0].toNullable()?.state, FitItemState.online);
      expect(converted.body.slots.tacticalMode.isNone(), isTrue);
    });

    test("extends racks beyond the layout when an index overflows", () {
      final converted = fitStateToStorage(
        FitState(
          shipTypeId: 12017,
          layout: _layout(high: 1),
          damageProfile: _profile(),
          modules: [
            FitModule(
              typeId: 12001,
              slotType: SlotType.HIGH,
              index: 2,
              state: Slots_SlotState.PASSIVE,
            ),
          ],
        ),
        characterId: "predefined_all_5",
      );

      expect(converted.body.slots.high, hasLength(3));
      expect(converted.body.slots.high[2].toNullable()?.state, FitItemState.passive);
    });

    test("restores dynamic items and dynamic module references", () {
      final converted = fitStateToStorage(
        FitState(
          shipTypeId: 12017,
          layout: _layout(high: 1),
          damageProfile: _profile(),
          modules: [
            FitModule(
              dynamicId: 7,
              slotType: SlotType.HIGH,
              index: 0,
              state: Slots_SlotState.OVERLOAD,
            ),
          ],
          dynamicItems: [
            fit_request.FitDynamicItem(
              dynamicId: 7,
              baseTypeId: 12001,
              typeId: 81001,
              attributes: [
                fit_request.FitDynamicAttribute(attributeId: 6, value: 1.5),
                fit_request.FitDynamicAttribute(attributeId: -30, value: 0.8),
              ],
            ),
          ],
        ),
        characterId: "predefined_all_5",
      );

      final item = converted.dynamicRegistry.dynamicItems[7];
      expect(item, isNotNull);
      expect(item!.originTypeId, 12001);
      expect(item.typeId, 81001);
      expect(item.dynamicAttributes[6], 1.5);
      expect(item.dynamicAttributes[-30], 0.8);

      final module = converted.body.slots.high[0].toNullable();
      expect(module?.itemId, const FitStorageItemId.dynamic(dynamicId: 7));
      expect(module?.state, FitItemState.overload);
    });

    test("falls back to the base type when a dynamic item has no mutated type", () {
      final converted = fitStateToStorage(
        FitState(
          shipTypeId: 12017,
          layout: _layout(),
          damageProfile: _profile(),
          dynamicItems: [fit_request.FitDynamicItem(dynamicId: 3, baseTypeId: 12001)],
        ),
        characterId: "predefined_all_5",
      );

      expect(converted.dynamicRegistry.dynamicItems[3]?.typeId, 12001);
    });

    test("maps the tactical mode", () {
      final converted = fitStateToStorage(
        FitState(
          shipTypeId: 12017,
          layout: _layout(),
          damageProfile: _profile(),
          tacticalModeTypeId: 62770,
        ),
        characterId: "predefined_all_5",
      );

      expect(converted.body.slots.tacticalMode.toNullable(), 62770);
    });

    test("maps drones, fighters, implants, and boosters", () {
      final converted = fitStateToStorage(
        FitState(
          shipTypeId: 12017,
          layout: _layout(),
          damageProfile: _profile(),
          drones: [FitDrone(typeId: 2456, state: Slots_SlotState.ACTIVE, quantity: 5)],
          fighters: [
            FitFighter(
              typeId: 40552,
              quantity: 2,
              maxSquadronSize: 3,
              group: SnapshotFighter_SquadronGroup.LIGHT,
              abilities: [SnapshotFighter_Ability.TURRET, SnapshotFighter_Ability.ATTACK_MISSILES],
            ),
            FitFighter(
              typeId: 23061,
              quantity: 1,
              maxSquadronSize: 1,
              group: SnapshotFighter_SquadronGroup.HEAVY,
              abilities: [SnapshotFighter_Ability.BOMB],
            ),
          ],
          implants: [
            FitImplant(slotIndex: 8, typeId: 13259, state: Slots_SlotState.ONLINE),
            FitImplant(slotIndex: 1, typeId: 13219, state: Slots_SlotState.ONLINE),
            FitImplant(slotIndex: 3, state: Slots_SlotState.PASSIVE),
          ],
          boosters: [FitBooster(slotIndex: 2, typeId: 28614, state: Slots_SlotState.ACTIVE)],
        ),
        characterId: "predefined_all_5",
      );

      final drone = converted.body.drones.single;
      expect(drone.itemId, const FitStorageItemId.item(id: 2456));
      expect(drone.state, FitItemState.active);
      expect(drone.quantity, 5);

      final fighters = converted.body.fighters;
      expect(fighters, hasLength(2));
      expect(fighters[0].groupId, 0);
      expect(fighters[0].fighterAbility, 0x01 | 0x04);
      expect(fighters[0].quantity, 2);
      expect(fighters[1].groupId, 1);
      expect(fighters[1].fighterAbility, 0x08);

      // Implants are ordered by slot index; empty slots are dropped.
      final implants = converted.body.implants;
      expect(implants, hasLength(2));
      expect(implants[0].itemId, const FitStorageItemId.item(id: 13219));
      expect(implants[1].itemId, const FitStorageItemId.item(id: 13259));

      final booster = converted.body.boosters.single;
      expect(booster.itemId, const FitStorageItemId.item(id: 28614));
      expect(booster.index, 2);
      expect(booster.state, FitItemState.active);
    });
  });
}
