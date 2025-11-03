part of "page.dart";

@freezed
abstract class SlotInfo with _$SlotInfo {
  const factory SlotInfo.empty({required int index}) = _EmptySlotInfo;
  const factory SlotInfo.item({
    required FitItemState state,
    required native.OutSlotType type,
    required int index,
    required FitModuleItem slot,
  }) = _ItemSlotInfo;
}

@freezed
abstract class SlotIdentifier with _$SlotIdentifier {
  const factory SlotIdentifier.high({required int index}) = _SlotIdentifierHigh;
  const factory SlotIdentifier.medium({required int index}) = _SlotIdentifierMedium;
  const factory SlotIdentifier.low({required int index}) = _SlotIdentifierLow;
  const factory SlotIdentifier.rig({required int index}) = _SlotIdentifierRig;
  const factory SlotIdentifier.subsystem({required int index}) = _SlotIdentifierSubsystem;
  const factory SlotIdentifier.tacticalMode() = _SlotIdentifierTacticalMode;
  const factory SlotIdentifier.service({required int index}) = _SlotIdentifierService;
  const factory SlotIdentifier.drone({required int groupId}) = _SlotIdentifierDrone;
  const factory SlotIdentifier.fighter({required int groupId}) = _SlotIdentifierFighter;
  const factory SlotIdentifier.implant({required int index}) = _SlotIdentifierImplant;
  const factory SlotIdentifier.booster({required int slotId}) = _SlotIdentifierBooster;
}
