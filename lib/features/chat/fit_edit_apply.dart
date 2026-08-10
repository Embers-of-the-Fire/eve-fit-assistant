import "package:eve_fit_assistant/data/proto/fit.pb.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fpdart/fpdart.dart";

/// Applies one batch of chat `apply_fit_edit` ops (decoded from the callback's
/// ops JSON) onto [fit], returning the updated fit.
///
/// The ops were already validated by the chat crate against the engine model;
/// this translator mirrors that validation leniently — anything that cannot
/// be applied to the storage model is skipped. [slotsInfo] provides the
/// implant slot metadata (`collection.slots`) needed to resolve implant slots.
FitStorage applyFitEditOps(FitStorage fit, List<Object?> ops, {required Slots slotsInfo}) {
  var current = fit;
  for (final op in ops) {
    if (op is! Map<String, dynamic>) continue;
    current = _applyOp(current, op, slotsInfo);
  }
  return current;
}

FitStorage _applyOp(FitStorage fit, Map<String, dynamic> op, Slots slotsInfo) {
  int? asInt(Object? value) => switch (value) {
    final int value => value,
    final num value => value.toInt(),
    _ => null,
  };
  Option<FitChargeItem> asCharge(Object? value) =>
      Option.fromNullable(asInt(value)).map((id) => FitChargeItem(typeId: id));

  final typeId = asInt(op["type_id"]);
  switch (op["op"]) {
    case "add_module":
      final slotType = op["slot_type"];
      if (slotType is! String || typeId == null) return fit;
      return _updateSlots(fit, slotType, (list) {
        final free = list.indexWhere((slot) => slot.isNone());
        if (free < 0) return list;
        final entries = list.toList();
        entries[free] = Some(
          FitModuleItem(
            itemId: FitStorageItemId.item(id: typeId),
            state: _moduleState(op["state"]) ?? FitItemState.active,
            charge: asCharge(op["charge_type_id"]),
          ),
        );
        return IList(entries);
      });
    case "remove_module":
      final slotType = op["slot_type"];
      final index = asInt(op["index"]);
      if (slotType is! String || index == null) return fit;
      return _updateSlots(fit, slotType, (list) {
        if (index < 0 || index >= list.length) return list;
        final entries = list.toList();
        entries[index] = const None();
        return IList(entries);
      });
    case "set_module_charge":
      final slotType = op["slot_type"];
      final index = asInt(op["index"]);
      if (slotType is! String || index == null) return fit;
      return _updateSlots(fit, slotType, (list) {
        if (index < 0 || index >= list.length) return list;
        final entries = list.toList();
        entries[index] = entries[index].map(
          (module) => module.copyWith(charge: asCharge(op["charge_type_id"])),
        );
        return IList(entries);
      });
    case "set_module_state":
      final slotType = op["slot_type"];
      final index = asInt(op["index"]);
      final state = _moduleState(op["state"]);
      if (slotType is! String || index == null || state == null) return fit;
      return _updateSlots(fit, slotType, (list) {
        if (index < 0 || index >= list.length) return list;
        final entries = list.toList();
        entries[index] = entries[index].map((module) => module.copyWith(state: state));
        return IList(entries);
      });
    case "add_drone":
      if (typeId == null) return fit;
      final state = _droneState(op["state"]) ?? FitItemState.passive;
      final drones = fit.body.drones.toList();
      final existing = drones.indexWhere(
        (drone) => _isPlainItem(drone.itemId, typeId) && drone.state == state,
      );
      if (existing >= 0) {
        drones[existing] = drones[existing].copyWith(quantity: drones[existing].quantity + 1);
      } else {
        drones.add(
          FitDroneItem(
            itemId: FitStorageItemId.item(id: typeId),
            state: state,
            quantity: 1,
          ),
        );
      }
      return fit.copyWith(body: fit.body.copyWith(drones: IList(drones)));
    case "remove_drone":
      if (typeId == null) return fit;
      return fit.copyWith(
        body: fit.body.copyWith(
          drones: fit.body.drones.removeWhere((drone) => _isPlainItem(drone.itemId, typeId)),
        ),
      );
    case "set_drone_state":
      if (typeId == null) return fit;
      final state = _droneState(op["state"]);
      if (state == null) return fit;
      final updated = fit.body.drones
          .map((drone) => _isPlainItem(drone.itemId, typeId) ? drone.copyWith(state: state) : drone)
          .toList();
      // Entries that now share (item, state) are merged into one.
      final merged = <FitDroneItem>[];
      for (final drone in updated) {
        final existing = merged.indexWhere(
          (entry) => entry.itemId == drone.itemId && entry.state == drone.state,
        );
        if (existing >= 0) {
          merged[existing] = merged[existing].copyWith(
            quantity: merged[existing].quantity + drone.quantity,
          );
        } else {
          merged.add(drone);
        }
      }
      return fit.copyWith(body: fit.body.copyWith(drones: IList(merged)));
    case "add_fighter":
      if (typeId == null) return fit;
      final ability = asInt(op["ability"]) ?? 0;
      final fighters = fit.body.fighters.toList();
      final existing = fighters.indexWhere(
        (fighter) => _isPlainItem(fighter.itemId, typeId) && fighter.fighterAbility == ability,
      );
      if (existing >= 0) {
        fighters[existing] = fighters[existing].copyWith(quantity: fighters[existing].quantity + 1);
      } else {
        fighters.add(
          FitFighterItem(
            itemId: FitStorageItemId.item(id: typeId),
            groupId: fighters.length,
            quantity: 1,
            fighterAbility: ability,
          ),
        );
      }
      return fit.copyWith(body: fit.body.copyWith(fighters: _normalizeFighters(fighters)));
    case "remove_fighter":
      if (typeId == null) return fit;
      final fighters = fit.body.fighters
          .where((fighter) => !_isPlainItem(fighter.itemId, typeId))
          .toList();
      return fit.copyWith(body: fit.body.copyWith(fighters: _normalizeFighters(fighters)));
    case "set_implant":
      final slot = asInt(op["slot"]);
      if (typeId == null || slot == null) return fit;
      if (slotsInfo.implantSlots[typeId]?.slotIndex != slot) return fit;
      final implants = fit.body.implants.toList();
      final existing = _implantStorageIndex(fit, slot, slotsInfo);
      final implant = FitImplantItem(
        itemId: FitStorageItemId.item(id: typeId),
        state: FitItemState.online,
      );
      if (existing != null) {
        implants[existing] = implant;
      } else {
        implants.add(implant);
      }
      return fit.copyWith(body: fit.body.copyWith(implants: IList(implants)));
    case "remove_implant":
      final slot = asInt(op["slot"]);
      if (slot == null) return fit;
      final existing = _implantStorageIndex(fit, slot, slotsInfo);
      if (existing == null) return fit;
      final implants = fit.body.implants.toList()..removeAt(existing);
      return fit.copyWith(body: fit.body.copyWith(implants: IList(implants)));
    case "set_booster":
      final slot = asInt(op["slot"]);
      if (typeId == null || slot == null) return fit;
      final boosters = fit.body.boosters.toList();
      final booster = FitBoosterItem(
        itemId: FitStorageItemId.item(id: typeId),
        index: slot,
        state: FitItemState.online,
      );
      final existing = boosters.indexWhere((entry) => entry.index == slot);
      if (existing >= 0) {
        boosters[existing] = booster;
      } else {
        boosters
          ..add(booster)
          ..sort((left, right) => left.index.compareTo(right.index));
      }
      return fit.copyWith(body: fit.body.copyWith(boosters: IList(boosters)));
    case "remove_booster":
      final slot = asInt(op["slot"]);
      if (slot == null) return fit;
      return fit.copyWith(
        body: fit.body.copyWith(
          boosters: fit.body.boosters.removeWhere((booster) => booster.index == slot),
        ),
      );
    default:
      return fit;
  }
}

bool _isPlainItem(FitStorageItemId itemId, int typeId) =>
    itemId is FitStorageItemIdItem && itemId.id == typeId;

FitItemState? _moduleState(Object? state) => switch (state) {
  "passive" => FitItemState.passive,
  "online" => FitItemState.online,
  "active" => FitItemState.active,
  "overload" => FitItemState.overload,
  _ => null,
};

FitItemState? _droneState(Object? state) => switch (state) {
  "bay" => FitItemState.passive,
  "space" => FitItemState.active,
  _ => null,
};

/// Updates one fixed module slot list (`high`/`medium`/`low`/`rig`/
/// `subsystem`/`service`); unknown slot types leave the fit unchanged.
FitStorage _updateSlots(
  FitStorage fit,
  String slotType,
  IList<Option<FitModuleItem>> Function(IList<Option<FitModuleItem>>) update,
) {
  final slots = fit.body.slots;
  final updated = switch (slotType) {
    "high" => slots.copyWith(high: update(slots.high)),
    "medium" => slots.copyWith(medium: update(slots.medium)),
    "low" => slots.copyWith(low: update(slots.low)),
    "rig" => slots.copyWith(rig: update(slots.rig)),
    "subsystem" => slots.copyWith(subsystem: update(slots.subsystem)),
    "service" => slots.copyWith(service: update(slots.service)),
    _ => slots,
  };
  if (identical(updated, slots)) return fit;
  return fit.copyWith(body: fit.body.copyWith(slots: updated));
}

IList<FitFighterItem> _normalizeFighters(List<FitFighterItem> fighters) =>
    IList(fighters.mapWithIndex((fighter, index) => fighter.copyWith(groupId: index)));

/// Implants are stored as a plain array; the authoritative slot of each
/// implant comes from the bundle metadata (1-based `slotIndex`). Resolves the
/// storage index of the implant occupying [slot], if any.
int? _implantStorageIndex(FitStorage fit, int slot, Slots slotsInfo) {
  for (final (index, implant) in fit.body.implants.mapWithIndex(
    (implant, index) => (index, implant),
  )) {
    final typeId = switch (implant.itemId) {
      FitStorageItemIdItem(:final id) => id,
      FitStorageItemIdDynamic(:final dynamicId) =>
        fit.dynamicRegistry.dynamicItems[dynamicId]?.typeId,
      _ => null,
    };
    if (typeId == null) continue;
    if (slotsInfo.implantSlots[typeId]?.slotIndex == slot) return index;
  }
  return null;
}
