import "package:efa_proto/fit.pb.dart";
import "package:eve_fit_assistant/features/chat/fit_edit_apply.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";

FitModuleItem _module(int typeId, [FitItemState state = FitItemState.active]) => FitModuleItem(
  itemId: FitStorageItemId.item(id: typeId),
  state: state,
  charge: const None(),
);

FitStorage _makeFit({
  IList<Option<FitModuleItem>>? high,
  IList<FitDroneItem>? drones,
  IList<FitFighterItem>? fighters,
  IList<FitImplantItem>? implants,
  IList<FitBoosterItem>? boosters,
}) => FitStorage(
  metadata: const FitMetadata(
    fitId: "test-fit-1",
    shipTypeId: 1234,
    name: "Test Fit",
    lastModified: 0,
    description: "",
    checkoutRef: CheckoutRef(checkoutId: "checkout-abc", serverId: "Serenity"),
  ),
  body: FitStorageBody(
    shipTypeId: 1234,
    characterId: "predefined_all_5",
    damageProfile: const FitDamageProfile(em: 0.25, explosive: 0.25, kinetic: 0.25, thermal: 0.25),
    slots: FitStorageSlots(
      high: high ?? const IList.empty(),
      medium: const IList.empty(),
      low: const IList.empty(),
      rig: const IList.empty(),
      subsystem: const IList.empty(),
      service: const IList.empty(),
      tacticalMode: const None(),
    ),
    drones: drones ?? const IList.empty(),
    fighters: fighters ?? const IList.empty(),
    implants: implants ?? const IList.empty(),
    boosters: boosters ?? const IList.empty(),
  ),
  dynamicRegistry: const FitDynamicRegistry(dynamicItems: IMap.empty()),
);

final _emptySlots = Slots();

final _implantSlots = Slots(
  implantSlots: [
    MapEntry(500, Slots_ImplantSlot(slotIndex: 1)),
    MapEntry(501, Slots_ImplantSlot(slotIndex: 2)),
    MapEntry(502, Slots_ImplantSlot(slotIndex: 2)),
  ],
);

void main() {
  group("module ops", () {
    test("add_module fills the first free slot, including gaps", () {
      final fit = _makeFit(high: IList([Some(_module(100)), const None(), Some(_module(102))]));
      final updated = applyFitEditOps(fit, [
        {"op": "add_module", "slot_type": "high", "type_id": 200},
      ], slotsInfo: _emptySlots);
      final high = updated.body.slots.high;
      expect(high.length, 3);
      final added = high[1].toNullable();
      expect(added, isNotNull);
      expect(added!.itemId, const FitStorageItemId.item(id: 200));
      expect(added.state, FitItemState.active);
      expect(added.charge.isNone(), isTrue);
    });

    test("add_module with state and charge", () {
      final fit = _makeFit(high: IList([const None()]));
      final updated = applyFitEditOps(fit, [
        {
          "op": "add_module",
          "slot_type": "high",
          "type_id": 200,
          "state": "online",
          "charge_type_id": 900,
        },
      ], slotsInfo: _emptySlots);
      final added = updated.body.slots.high[0].toNullable()!;
      expect(added.state, FitItemState.online);
      expect(added.charge.toNullable()?.typeId, 900);
    });

    test("add_module on a full slot group is a no-op", () {
      final fit = _makeFit(high: IList([Some(_module(100))]));
      final updated = applyFitEditOps(fit, [
        {"op": "add_module", "slot_type": "high", "type_id": 200},
      ], slotsInfo: _emptySlots);
      expect(updated.body.slots.high.length, 1);
      expect(updated.body.slots.high[0].toNullable()!.itemId, const FitStorageItemId.item(id: 100));
    });

    test("remove_module and out-of-range removal", () {
      final fit = _makeFit(high: IList([Some(_module(100))]));
      final updated = applyFitEditOps(fit, [
        {"op": "remove_module", "slot_type": "high", "index": 0},
        {"op": "remove_module", "slot_type": "high", "index": 7},
      ], slotsInfo: _emptySlots);
      expect(updated.body.slots.high[0].isNone(), isTrue);
    });

    test("set_module_charge sets and clears", () {
      final fit = _makeFit(high: IList([Some(_module(100))]));
      var updated = applyFitEditOps(fit, [
        {"op": "set_module_charge", "slot_type": "high", "index": 0, "charge_type_id": 900},
      ], slotsInfo: _emptySlots);
      expect(updated.body.slots.high[0].toNullable()!.charge.toNullable()?.typeId, 900);
      updated = applyFitEditOps(updated, [
        {"op": "set_module_charge", "slot_type": "high", "index": 0},
      ], slotsInfo: _emptySlots);
      expect(updated.body.slots.high[0].toNullable()!.charge.isNone(), isTrue);
    });

    test("set_module_state", () {
      final fit = _makeFit(high: IList([Some(_module(100))]));
      final updated = applyFitEditOps(fit, [
        {"op": "set_module_state", "slot_type": "high", "index": 0, "state": "overload"},
      ], slotsInfo: _emptySlots);
      expect(updated.body.slots.high[0].toNullable()!.state, FitItemState.overload);
    });
  });

  group("drone ops", () {
    test("add_drone increments quantity for the same type and state", () {
      final fit = _makeFit(
        drones: IList([
          const FitDroneItem(
            itemId: FitStorageItemId.item(id: 300),
            state: FitItemState.passive,
            quantity: 2,
          ),
        ]),
      );
      final updated = applyFitEditOps(fit, [
        {"op": "add_drone", "type_id": 300},
      ], slotsInfo: _emptySlots);
      expect(updated.body.drones.length, 1);
      expect(updated.body.drones[0].quantity, 3);
    });

    test("add_drone with a different state starts a new entry", () {
      final fit = _makeFit(
        drones: IList([
          const FitDroneItem(
            itemId: FitStorageItemId.item(id: 300),
            state: FitItemState.passive,
            quantity: 2,
          ),
        ]),
      );
      final updated = applyFitEditOps(fit, [
        {"op": "add_drone", "type_id": 300, "state": "space"},
      ], slotsInfo: _emptySlots);
      expect(updated.body.drones.length, 2);
      expect(updated.body.drones[1].state, FitItemState.active);
      expect(updated.body.drones[1].quantity, 1);
    });

    test("set_drone_state updates and merges entries", () {
      final fit = _makeFit(
        drones: IList([
          const FitDroneItem(
            itemId: FitStorageItemId.item(id: 300),
            state: FitItemState.passive,
            quantity: 2,
          ),
          const FitDroneItem(
            itemId: FitStorageItemId.item(id: 300),
            state: FitItemState.active,
            quantity: 3,
          ),
          const FitDroneItem(
            itemId: FitStorageItemId.item(id: 301),
            state: FitItemState.active,
            quantity: 1,
          ),
        ]),
      );
      final updated = applyFitEditOps(fit, [
        {"op": "set_drone_state", "type_id": 300, "state": "space"},
      ], slotsInfo: _emptySlots);
      expect(updated.body.drones.length, 2);
      final merged = updated.body.drones.firstWhere(
        (drone) => drone.itemId == const FitStorageItemId.item(id: 300),
      );
      expect(merged.state, FitItemState.active);
      expect(merged.quantity, 5);
    });

    test("remove_drone removes every entry of the type", () {
      final fit = _makeFit(
        drones: IList([
          const FitDroneItem(
            itemId: FitStorageItemId.item(id: 300),
            state: FitItemState.passive,
            quantity: 2,
          ),
          const FitDroneItem(
            itemId: FitStorageItemId.item(id: 300),
            state: FitItemState.active,
            quantity: 1,
          ),
        ]),
      );
      final updated = applyFitEditOps(fit, [
        {"op": "remove_drone", "type_id": 300},
      ], slotsInfo: _emptySlots);
      expect(updated.body.drones, isEmpty);
    });
  });

  group("fighter ops", () {
    test("add_fighter creates a normalized group and increments on repeat", () {
      var fit = _makeFit();
      fit = applyFitEditOps(fit, [
        {"op": "add_fighter", "type_id": 400, "ability": 5},
      ], slotsInfo: _emptySlots);
      expect(fit.body.fighters.length, 1);
      expect(fit.body.fighters[0].groupId, 0);
      expect(fit.body.fighters[0].fighterAbility, 5);
      expect(fit.body.fighters[0].quantity, 1);

      fit = applyFitEditOps(fit, [
        {"op": "add_fighter", "type_id": 400, "ability": 5},
      ], slotsInfo: _emptySlots);
      expect(fit.body.fighters.length, 1);
      expect(fit.body.fighters[0].quantity, 2);
    });

    test("remove_fighter removes all of the type and renormalizes groups", () {
      final fit = _makeFit(
        fighters: IList([
          const FitFighterItem(
            itemId: FitStorageItemId.item(id: 400),
            groupId: 0,
            quantity: 2,
            fighterAbility: 0,
          ),
          const FitFighterItem(
            itemId: FitStorageItemId.item(id: 401),
            groupId: 1,
            quantity: 1,
            fighterAbility: 0,
          ),
        ]),
      );
      final updated = applyFitEditOps(fit, [
        {"op": "remove_fighter", "type_id": 400},
      ], slotsInfo: _emptySlots);
      expect(updated.body.fighters.length, 1);
      expect(updated.body.fighters[0].itemId, const FitStorageItemId.item(id: 401));
      expect(updated.body.fighters[0].groupId, 0);
    });
  });

  group("implant ops", () {
    test("set_implant appends and replaces by bundle slot metadata", () {
      var fit = _makeFit();
      fit = applyFitEditOps(fit, [
        {"op": "set_implant", "type_id": 500, "slot": 1},
        {"op": "set_implant", "type_id": 501, "slot": 2},
      ], slotsInfo: _implantSlots);
      expect(fit.body.implants.length, 2);

      // Type 502 occupies slot 2; replacing slot 2 with type 502 reuses its
      // storage position instead of appending.
      fit = applyFitEditOps(fit, [
        {"op": "set_implant", "type_id": 502, "slot": 2},
      ], slotsInfo: _implantSlots);
      expect(fit.body.implants.length, 2);
      expect(fit.body.implants[1].itemId, const FitStorageItemId.item(id: 502));
    });

    test("set_implant with a type and slot mismatch is skipped", () {
      final fit = _makeFit(
        implants: IList(const [
          FitImplantItem(itemId: FitStorageItemId.item(id: 501), state: FitItemState.online),
        ]),
      );
      final updated = applyFitEditOps(fit, [
        {"op": "set_implant", "type_id": 500, "slot": 2},
      ], slotsInfo: _implantSlots);
      expect(updated.body.implants.length, 1);
      expect(updated.body.implants[0].itemId, const FitStorageItemId.item(id: 501));
    });

    test("remove_implant resolves the slot through bundle metadata", () {
      final fit = _makeFit(
        implants: IList([
          const FitImplantItem(itemId: FitStorageItemId.item(id: 501), state: FitItemState.online),
        ]),
      );
      final updated = applyFitEditOps(fit, [
        {"op": "remove_implant", "slot": 2},
      ], slotsInfo: _implantSlots);
      expect(updated.body.implants, isEmpty);
    });
  });

  group("booster ops", () {
    test("set_booster adds sorted and replaces by slot", () {
      var fit = _makeFit();
      fit = applyFitEditOps(fit, [
        {"op": "set_booster", "type_id": 600, "slot": 3},
        {"op": "set_booster", "type_id": 601, "slot": 1},
      ], slotsInfo: _emptySlots);
      expect(fit.body.boosters.length, 2);
      expect(fit.body.boosters[0].index, 1);
      expect(fit.body.boosters[1].index, 3);

      fit = applyFitEditOps(fit, [
        {"op": "set_booster", "type_id": 602, "slot": 3},
      ], slotsInfo: _emptySlots);
      expect(fit.body.boosters.length, 2);
      expect(fit.body.boosters[1].itemId, const FitStorageItemId.item(id: 602));
    });

    test("remove_booster removes by slot", () {
      final fit = _makeFit(
        boosters: IList([
          const FitBoosterItem(
            itemId: FitStorageItemId.item(id: 600),
            index: 1,
            state: FitItemState.online,
          ),
        ]),
      );
      final updated = applyFitEditOps(fit, [
        {"op": "remove_booster", "slot": 1},
      ], slotsInfo: _emptySlots);
      expect(updated.body.boosters, isEmpty);
    });
  });

  test("unknown and malformed ops are skipped", () {
    final fit = _makeFit(high: IList([Some(_module(100))]));
    final updated = applyFitEditOps(fit, [
      "not a map",
      {"op": "nonsense"},
      {"op": "add_module", "slot_type": "tactical_mode", "type_id": 200},
      {"op": "add_module", "slot_type": "high"},
    ], slotsInfo: _emptySlots);
    expect(updated.body.slots.high.length, 1);
    expect(updated.body.slots.high[0].toNullable()!.itemId, const FitStorageItemId.item(id: 100));
  });
}
