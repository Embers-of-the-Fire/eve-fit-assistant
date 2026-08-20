import "dart:math";

import "package:efa_proto/fit_request.pb.dart" hide FitDynamicItem;
import "package:efa_proto/fit_snapshot.pb.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/utils/native_convert.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fpdart/fpdart.dart";

/// The result of converting a canonical `FitState` (retrieved from the
/// platform fit storage by fit hash) back into storage models.
typedef FitStateConversion = ({FitStorageBody body, FitDynamicRegistry dynamicRegistry});

/// Inverse of `buildFitUploadRequest` (`lib/features/fit_io/upload_request.dart`).
///
/// The mutator type of dynamic items is not part of the wire format, so
/// imported abyssal items carry `modifierTypeId = 0` and cannot be re-rolled.
FitStateConversion fitStateToStorage(FitState state, {required String characterId}) {
  final dynamicRegistry = FitDynamicRegistry(
    dynamicItems: IMap.fromEntries([
      for (final item in state.dynamicItems)
        MapEntry(
          item.dynamicId,
          FitDynamicItem(
            dynamicItemId: item.dynamicId,
            originTypeId: item.baseTypeId,
            typeId: item.hasTypeId() ? item.typeId : item.baseTypeId,
            modifierTypeId: 0,
            dynamicAttributes: IMap.fromEntries([
              for (final attribute in item.attributes)
                MapEntry(attribute.attributeId, attribute.value),
            ]),
          ),
        ),
    ]),
  );

  FitStorageItemId moduleItemId(FitModule module) => switch (module.whichItem()) {
    FitModule_Item.dynamicId => FitStorageItemId.dynamic(dynamicId: module.dynamicId),
    _ => FitStorageItemId.item(id: module.typeId),
  };

  IList<Option<FitModuleItem>> buildRack(SlotType slotType, int layoutSize) {
    final modules = state.modules.where((module) => module.slotType == slotType);
    final size = modules.fold(layoutSize, (size, module) => max(size, module.index + 1));
    final rack = List<Option<FitModuleItem>>.filled(size, const Option<FitModuleItem>.none());
    for (final module in modules) {
      rack[module.index] = Option.of(
        FitModuleItem(
          itemId: moduleItemId(module),
          state: module.state.dartImpl,
          charge: module.hasChargeTypeId()
              ? Option.of(FitChargeItem(typeId: module.chargeTypeId))
              : const Option<FitChargeItem>.none(),
        ),
      );
    }
    return IList(rack);
  }

  final implants = [...state.implants]..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));

  return (
    body: FitStorageBody(
      shipTypeId: state.shipTypeId,
      characterId: characterId,
      damageProfile: FitDamageProfile(
        em: state.damageProfile.em,
        explosive: state.damageProfile.explosive,
        kinetic: state.damageProfile.kinetic,
        thermal: state.damageProfile.thermal,
      ),
      slots: FitStorageSlots(
        high: buildRack(SlotType.HIGH, state.layout.highSlots),
        medium: buildRack(SlotType.MEDIUM, state.layout.mediumSlots),
        low: buildRack(SlotType.LOW, state.layout.lowSlots),
        rig: buildRack(SlotType.RIG, state.layout.rigSlots),
        subsystem: buildRack(SlotType.SUBSYSTEM, state.layout.subsystemSlots),
        service: buildRack(SlotType.SERVICE, state.layout.serviceSlots),
        tacticalMode: state.hasTacticalModeTypeId()
            ? Option.of(state.tacticalModeTypeId)
            : const Option<int>.none(),
      ),
      drones: IList([
        for (final drone in state.drones)
          FitDroneItem(
            itemId: FitStorageItemId.item(id: drone.typeId),
            state: drone.state.dartImpl,
            quantity: drone.quantity,
          ),
      ]),
      fighters: IList([
        for (final (index, fighter) in state.fighters.indexed)
          FitFighterItem(
            itemId: FitStorageItemId.item(id: fighter.typeId),
            groupId: index,
            quantity: fighter.quantity,
            fighterAbility: fighter.abilities.fold(0, (bits, ability) => bits | ability.bitMask),
          ),
      ]),
      implants: IList([
        for (final implant in implants)
          if (implant.hasTypeId())
            FitImplantItem(
              itemId: FitStorageItemId.item(id: implant.typeId),
              state: implant.state.dartImpl,
            ),
      ]),
      boosters: IList([
        for (final booster in state.boosters)
          FitBoosterItem(
            itemId: FitStorageItemId.item(id: booster.typeId),
            index: booster.slotIndex,
            state: booster.state.dartImpl,
          ),
      ]),
    ),
    dynamicRegistry: dynamicRegistry,
  );
}

extension on SnapshotFighter_Ability {
  /// The engine input bitmask (1=TURRET, 2=MISSILES, 4=ATTACK_MISSILES,
  /// 8=BOMB), mirroring the encoding in `buildFitUploadRequest`.
  int get bitMask => switch (this) {
    SnapshotFighter_Ability.TURRET => 0x01,
    SnapshotFighter_Ability.MISSILES => 0x02,
    SnapshotFighter_Ability.ATTACK_MISSILES => 0x04,
    SnapshotFighter_Ability.BOMB => 0x08,
    _ => 0,
  };
}
