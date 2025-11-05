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
  const factory SlotIdentifier.high({required int index}) = SlotIdentifierHigh;
  const factory SlotIdentifier.medium({required int index}) = SlotIdentifierMedium;
  const factory SlotIdentifier.low({required int index}) = SlotIdentifierLow;
  const factory SlotIdentifier.rig({required int index}) = SlotIdentifierRig;
  const factory SlotIdentifier.subsystem({required int index}) = SlotIdentifierSubsystem;
  const factory SlotIdentifier.tacticalMode() = SlotIdentifierTacticalMode;
  const factory SlotIdentifier.service({required int index}) = SlotIdentifierService;
  const factory SlotIdentifier.drone({required int groupId}) = SlotIdentifierDrone;
  const factory SlotIdentifier.fighter({required int groupId}) = SlotIdentifierFighter;
  const factory SlotIdentifier.implant({required int index}) = SlotIdentifierImplant;
  const factory SlotIdentifier.booster({required int slotId}) = SlotIdentifierBooster;

  const SlotIdentifier._();

  int get asIndexed => when(
    high: (index) => index,
    medium: (index) => index,
    low: (index) => index,
    rig: (index) => index,
    subsystem: (index) => index,
    tacticalMode: () => 0,
    service: (index) => index,
    drone: (groupId) => groupId,
    fighter: (groupId) => groupId,
    implant: (index) => index,
    booster: (slotId) => slotId - 1, // boosters are 1-indexed
  );
}
