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
  const factory SlotIdentifier.subsystem({required SubsystemType type}) = SlotIdentifierSubsystem;
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
    subsystem: (type) => type.index,
    tacticalMode: () => 0,
    service: (index) => index,
    drone: (groupId) => groupId,
    fighter: (groupId) => groupId,
    implant: (index) => index,
    booster: (slotId) => slotId - 1, // boosters are 1-indexed
  );

  String localizedAddItemDialogTitle(BuildContext context) => when(
    high: (index) => context.l10n.fitAddItemDialogTitleWithIndex(
      slotName: context.l10n.highSlot,
      index: index + 1,
    ),
    medium: (index) => context.l10n.fitAddItemDialogTitleWithIndex(
      slotName: context.l10n.midSlot,
      index: index + 1,
    ),
    low: (index) => context.l10n.fitAddItemDialogTitleWithIndex(
      slotName: context.l10n.lowSlot,
      index: index + 1,
    ),
    rig: (index) => context.l10n.fitAddItemDialogTitleWithIndex(
      slotName: context.l10n.rigSlot,
      index: index + 1,
    ),
    subsystem: (type) => context.l10n.fitAddItemDialogTitleWithIndex(
      slotName: context.l10n.subsystemSlot,
      index: type.index + 1,
    ),
    tacticalMode: () => context.l10n.fitAddItemDialogTitle(slotName: context.l10n.tacticalMode),
    service: (index) => context.l10n.fitAddItemDialogTitleWithIndex(
      slotName: context.l10n.serviceSlot,
      index: index + 1,
    ),
    drone: (groupId) => context.l10n.fitAddItemDialogTitleWithIndex(
      slotName: context.l10n.drone,
      index: groupId + 1,
    ),
    fighter: (groupId) => context.l10n.fitAddItemDialogTitleWithIndex(
      slotName: context.l10n.fighter,
      index: groupId + 1,
    ),
    implant: (index) => context.l10n.fitAddItemDialogTitleWithIndex(
      slotName: context.l10n.implantSlot,
      index: index + 1,
    ),
    booster: (slotId) => context.l10n.fitAddItemDialogTitleWithIndex(
      slotName: context.l10n.boosterSlot,
      index: slotId,
    ),
  );

  String localizedSlotName(BuildContext context) => when(
    high: (_) => context.l10n.highSlot,
    medium: (_) => context.l10n.midSlot,
    low: (_) => context.l10n.lowSlot,
    rig: (_) => context.l10n.rigSlot,
    subsystem: (_) => context.l10n.subsystemSlot,
    tacticalMode: () => context.l10n.tacticalMode,
    service: (_) => context.l10n.serviceSlot,
    drone: (_) => context.l10n.drone,
    fighter: (_) => context.l10n.fighter,
    implant: (_) => context.l10n.implantSlot,
    booster: (_) => context.l10n.boosterSlot,
  );

  int get baseMarketGroupId => when(
    high: (_) => EveConstMarketGroupId.equipment,
    medium: (_) => EveConstMarketGroupId.equipment,
    low: (_) => EveConstMarketGroupId.equipment,
    rig: (_) => EveConstMarketGroupId.rig,
    subsystem: (_) => EveConstMarketGroupId.subsystem,
    tacticalMode: () => 0,
    service: (_) => EveConstMarketGroupId.subsystem,
    drone: (_) => EveConstMarketGroupId.drone,
    fighter: (_) => EveConstMarketGroupId.fighter,
    implant: (_) => EveConstMarketGroupId.implant,
    booster: (_) => EveConstMarketGroupId.booster,
  );

  bool Function(EveSelectListRoot) validator(WidgetRef ref) {
    final slotsInfo = ref.watch(bundleCollectionGetSlotsProvider);
    if (slotsInfo == null) return (_) => true;

    return when(
      high: (_) =>
          (node) => switch (node) {
            EveSelectListRootType(:final typeId) => slotsInfo.highSlots.containsKey(typeId),
            _ => true,
          },
      medium: (_) =>
          (node) => switch (node) {
            EveSelectListRootType(:final typeId) => slotsInfo.mediumSlots.containsKey(typeId),
            _ => true,
          },
      low: (_) =>
          (node) => switch (node) {
            EveSelectListRootType(:final typeId) => slotsInfo.lowSlots.containsKey(typeId),
            _ => true,
          },
      rig: (_) =>
          (node) => switch (node) {
            EveSelectListRootType(:final typeId) => slotsInfo.rigSlots.containsKey(typeId),
            _ => true,
          },
      subsystem: (_) =>
          (node) => switch (node) {
            EveSelectListRootType(:final typeId) => slotsInfo.subsystemSlots.containsKey(typeId),
            _ => true,
          },
      tacticalMode: () =>
          (_) => true,
      service: (_) =>
          (node) => switch (node) {
            EveSelectListRootType(:final typeId) => slotsInfo.serviceSlots.containsKey(typeId),
            _ => true,
          },
      drone: (_) =>
          (node) => true,
      fighter: (_) =>
          (node) => switch (node) {
            EveSelectListRootMarketGroup(:final marketGroupId) =>
              marketGroupId == EveConstMarketGroupId.fighter,
            _ => true,
          },
      implant: (_) =>
          (node) => switch (node) {
            EveSelectListRootType(:final typeId) => slotsInfo.implantSlots.containsKey(typeId),
            _ => true,
          },
      booster: (_) =>
          (node) => switch (node) {
            EveSelectListRootType(:final typeId) => slotsInfo.boosterSlots.containsKey(typeId),
            _ => true,
          },
    );
  }
}
