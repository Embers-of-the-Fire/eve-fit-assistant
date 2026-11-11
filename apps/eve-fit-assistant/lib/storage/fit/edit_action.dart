import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:flutter/foundation.dart";

/// Slot kinds addressable by a [FitEditAction].
///
/// This is a value-only mirror of the fit's storage slots plus the item
/// collections that behave like slots in the editor (drones, fighters,
/// implants, boosters). It intentionally carries no repository objects.
enum FitSlotKind { high, medium, low, rig, subsystem, service, drone, fighter, implant, booster }

/// Operation carried by system-effect descriptors.
enum FitEditOperation { add, update, remove, apply }

/// The closed set of history action kinds.
enum FitEditKind {
  openedFit,
  equipModule,
  removeModule,
  addCharge,
  removeCharge,
  toggleModuleState,
  setImplant,
  removeImplant,
  applyImplantSet,
  setBooster,
  removeBooster,
  systemBuff,
  systemEffectPreset,
  setSecurityStatus,
  setDamageProfile,
  setCharacter,
  setTacticalMode,
  clearSlots,
  adjustSubsystem,
  editDynamicAttributes,
  aiEdit,
  renameFit,
  editDescription,

  // Value-only extensions for editor mutations that do not fit the semantic
  // kinds above (charges, quantities, fighter abilities, and dynamic items).
  clearCharges,
  clearSystemBuffs,
  setModuleQuantity,
  setFighterAbility,
  setDamageTurns,
  copyModule,
  fillModules,
  convertDynamic,
  mutateDynamic,
  revertDynamic,
}

/// Immutable, locale-independent description of one fit edit.
///
/// Descriptors contain only value types: numeric ids, slot kinds, booleans,
/// strings, and numeric values. They never contain localized text, resolved
/// type/ship objects, emulator output, or repository references.
@immutable
class FitEditAction {
  const FitEditAction._({
    required this.kind,
    this.typeId,
    this.moduleTypeId,
    this.chargeTypeId,
    this.slotKind,
    this.slotId,
    this.setId,
    this.buffId,
    this.presetId,
    this.operation,
    this.replaced = false,
    this.online = false,
    this.value,
    this.damageProfile,
    this.characterId,
    this.opCount,
    this.quantity,
    this.turns,
  });

  const FitEditAction.openedFit() : this._(kind: FitEditKind.openedFit);
  const FitEditAction.renameFit() : this._(kind: FitEditKind.renameFit);
  const FitEditAction.editDescription() : this._(kind: FitEditKind.editDescription);
  const FitEditAction.clearSystemBuffs() : this._(kind: FitEditKind.clearSystemBuffs);

  factory FitEditAction.equipModule({required int typeId, required FitSlotKind slotKind}) =>
      FitEditAction._(kind: FitEditKind.equipModule, typeId: typeId, slotKind: slotKind);

  factory FitEditAction.removeModule({required int typeId, required FitSlotKind slotKind}) =>
      FitEditAction._(kind: FitEditKind.removeModule, typeId: typeId, slotKind: slotKind);

  factory FitEditAction.addCharge({
    required int moduleTypeId,
    required int chargeTypeId,
    required bool replaced,
  }) => FitEditAction._(
    kind: FitEditKind.addCharge,
    moduleTypeId: moduleTypeId,
    chargeTypeId: chargeTypeId,
    replaced: replaced,
  );

  factory FitEditAction.removeCharge({required int moduleTypeId}) =>
      FitEditAction._(kind: FitEditKind.removeCharge, moduleTypeId: moduleTypeId);

  factory FitEditAction.toggleModuleState({required int typeId, required bool online}) =>
      FitEditAction._(kind: FitEditKind.toggleModuleState, typeId: typeId, online: online);

  factory FitEditAction.setImplant({required int typeId, required int slotId}) =>
      FitEditAction._(kind: FitEditKind.setImplant, typeId: typeId, slotId: slotId);

  factory FitEditAction.removeImplant({required int slotId}) =>
      FitEditAction._(kind: FitEditKind.removeImplant, slotId: slotId);

  factory FitEditAction.applyImplantSet({required int setId}) =>
      FitEditAction._(kind: FitEditKind.applyImplantSet, setId: setId);

  factory FitEditAction.setBooster({required int typeId}) =>
      FitEditAction._(kind: FitEditKind.setBooster, typeId: typeId);

  factory FitEditAction.removeBooster({required int slotId}) =>
      FitEditAction._(kind: FitEditKind.removeBooster, slotId: slotId);

  factory FitEditAction.systemBuff({required int buffId, required FitEditOperation operation}) =>
      FitEditAction._(kind: FitEditKind.systemBuff, buffId: buffId, operation: operation);

  factory FitEditAction.systemEffectPreset({
    required String presetId,
    required FitEditOperation operation,
  }) => FitEditAction._(
    kind: FitEditKind.systemEffectPreset,
    presetId: presetId,
    operation: operation,
  );

  factory FitEditAction.setSecurityStatus({required double value}) =>
      FitEditAction._(kind: FitEditKind.setSecurityStatus, value: value);

  factory FitEditAction.setDamageProfile({required FitDamageProfile values}) =>
      FitEditAction._(kind: FitEditKind.setDamageProfile, damageProfile: values);

  factory FitEditAction.setCharacter({required String characterId}) =>
      FitEditAction._(kind: FitEditKind.setCharacter, characterId: characterId);

  factory FitEditAction.setTacticalMode({required int typeId}) =>
      FitEditAction._(kind: FitEditKind.setTacticalMode, typeId: typeId);

  factory FitEditAction.clearSlots({required FitSlotKind slotKind}) =>
      FitEditAction._(kind: FitEditKind.clearSlots, slotKind: slotKind);

  factory FitEditAction.clearCharges({required FitSlotKind slotKind}) =>
      FitEditAction._(kind: FitEditKind.clearCharges, slotKind: slotKind);

  factory FitEditAction.adjustSubsystem({required int typeId}) =>
      FitEditAction._(kind: FitEditKind.adjustSubsystem, typeId: typeId);

  factory FitEditAction.editDynamicAttributes({required int typeId}) =>
      FitEditAction._(kind: FitEditKind.editDynamicAttributes, typeId: typeId);

  factory FitEditAction.aiEdit({required int opCount}) =>
      FitEditAction._(kind: FitEditKind.aiEdit, opCount: opCount);

  factory FitEditAction.setModuleQuantity({required int typeId, required int quantity}) =>
      FitEditAction._(kind: FitEditKind.setModuleQuantity, typeId: typeId, quantity: quantity);

  factory FitEditAction.setFighterAbility({required int typeId}) =>
      FitEditAction._(kind: FitEditKind.setFighterAbility, typeId: typeId);

  factory FitEditAction.setDamageTurns({required int typeId, required int turns}) =>
      FitEditAction._(kind: FitEditKind.setDamageTurns, typeId: typeId, turns: turns);

  factory FitEditAction.copyModule({required int typeId, required FitSlotKind slotKind}) =>
      FitEditAction._(kind: FitEditKind.copyModule, typeId: typeId, slotKind: slotKind);

  factory FitEditAction.fillModules({required int typeId, required FitSlotKind slotKind}) =>
      FitEditAction._(kind: FitEditKind.fillModules, typeId: typeId, slotKind: slotKind);

  factory FitEditAction.convertDynamic({required int typeId}) =>
      FitEditAction._(kind: FitEditKind.convertDynamic, typeId: typeId);

  factory FitEditAction.mutateDynamic({required int typeId}) =>
      FitEditAction._(kind: FitEditKind.mutateDynamic, typeId: typeId);

  factory FitEditAction.revertDynamic({required int typeId}) =>
      FitEditAction._(kind: FitEditKind.revertDynamic, typeId: typeId);

  final FitEditKind kind;
  final int? typeId;
  final int? moduleTypeId;
  final int? chargeTypeId;
  final FitSlotKind? slotKind;
  final int? slotId;
  final int? setId;
  final int? buffId;
  final String? presetId;
  final FitEditOperation? operation;
  final bool replaced;
  final bool online;
  final double? value;
  final FitDamageProfile? damageProfile;
  final String? characterId;
  final int? opCount;
  final int? quantity;
  final int? turns;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitEditAction &&
          other.kind == kind &&
          other.typeId == typeId &&
          other.moduleTypeId == moduleTypeId &&
          other.chargeTypeId == chargeTypeId &&
          other.slotKind == slotKind &&
          other.slotId == slotId &&
          other.setId == setId &&
          other.buffId == buffId &&
          other.presetId == presetId &&
          other.operation == operation &&
          other.replaced == replaced &&
          other.online == online &&
          other.value == value &&
          other.damageProfile == damageProfile &&
          other.characterId == characterId &&
          other.opCount == opCount &&
          other.quantity == quantity &&
          other.turns == turns;

  @override
  int get hashCode => Object.hashAll([
    kind,
    typeId,
    moduleTypeId,
    chargeTypeId,
    slotKind,
    slotId,
    setId,
    buffId,
    presetId,
    operation,
    replaced,
    online,
    value,
    damageProfile,
    characterId,
    opCount,
    quantity,
    turns,
  ]);

  @override
  String toString() => "FitEditAction(${kind.name})";
}
