part of "page.dart";

sealed class SlotInfo {
  const SlotInfo();

  const factory SlotInfo.empty({required int index}) = _EmptySlotInfo;
  const factory SlotInfo.item({
    required FitItemState state,
    required native.OutSlotType type,
    required int index,
    required FitModuleItem slot,
  }) = _ItemSlotInfo;
}

final class _EmptySlotInfo extends SlotInfo {
  const _EmptySlotInfo({required this.index});

  final int index;
}

final class _ItemSlotInfo extends SlotInfo {
  const _ItemSlotInfo({
    required this.state,
    required this.type,
    required this.index,
    required this.slot,
  });

  final FitItemState state;
  final native.OutSlotType type;
  final int index;
  final FitModuleItem slot;
}

sealed class SlotIdentifier {
  const SlotIdentifier();

  const factory SlotIdentifier.high({required int index}) = SlotIdentifierHigh;
  const factory SlotIdentifier.medium({required int index}) = SlotIdentifierMedium;
  const factory SlotIdentifier.low({required int index}) = SlotIdentifierLow;
  const factory SlotIdentifier.rig({required int index}) = SlotIdentifierRig;
  const factory SlotIdentifier.subsystem({required SubsystemType type}) = SlotIdentifierSubsystem;
  const factory SlotIdentifier.tacticalMode() = SlotIdentifierTacticalMode;
  const factory SlotIdentifier.service({required int index}) = SlotIdentifierService;
  const factory SlotIdentifier.drone({required int index}) = SlotIdentifierDrone;
  const factory SlotIdentifier.fighter({required int index}) = SlotIdentifierFighter;
  const factory SlotIdentifier.implant({required int index}) = SlotIdentifierImplant;
  const factory SlotIdentifier.booster({required int slotId}) = SlotIdentifierBooster;

  int get asIndexed => switch (this) {
    SlotIdentifierHigh(:final index) => index,
    SlotIdentifierMedium(:final index) => index,
    SlotIdentifierLow(:final index) => index,
    SlotIdentifierRig(:final index) => index,
    SlotIdentifierSubsystem(:final type) => type.index,
    SlotIdentifierTacticalMode() => 0,
    SlotIdentifierService(:final index) => index,
    SlotIdentifierDrone(:final index) => index,
    SlotIdentifierFighter(:final index) => index,
    SlotIdentifierImplant(:final index) => index,
    SlotIdentifierBooster(:final slotId) => slotId - 1,
  };

  String localizedAddItemDialogTitle(BuildContext context) => switch (this) {
    SlotIdentifierHigh(:final index) => context.l10n.fitAddItemDialogTitleWithIndex(
      slotName: context.l10n.highSlot,
      index: index + 1,
    ),
    SlotIdentifierMedium(:final index) => context.l10n.fitAddItemDialogTitleWithIndex(
      slotName: context.l10n.midSlot,
      index: index + 1,
    ),
    SlotIdentifierLow(:final index) => context.l10n.fitAddItemDialogTitleWithIndex(
      slotName: context.l10n.lowSlot,
      index: index + 1,
    ),
    SlotIdentifierRig(:final index) => context.l10n.fitAddItemDialogTitleWithIndex(
      slotName: context.l10n.rigSlot,
      index: index + 1,
    ),
    SlotIdentifierSubsystem(:final type) => context.l10n.fitAddItemDialogTitleWithIndex(
      slotName: context.l10n.subsystemSlot,
      index: type.index + 1,
    ),
    SlotIdentifierTacticalMode() => context.l10n.fitAddItemDialogTitle(
      slotName: context.l10n.tacticalMode,
    ),
    SlotIdentifierService(:final index) => context.l10n.fitAddItemDialogTitleWithIndex(
      slotName: context.l10n.serviceSlot,
      index: index + 1,
    ),
    SlotIdentifierDrone(:final index) => context.l10n.fitAddItemDialogTitleWithIndex(
      slotName: context.l10n.drone,
      index: index + 1,
    ),
    SlotIdentifierFighter(:final index) => context.l10n.fitAddItemDialogTitleWithIndex(
      slotName: context.l10n.fighter,
      index: index + 1,
    ),
    SlotIdentifierImplant(:final index) => context.l10n.fitAddItemDialogTitleWithIndex(
      slotName: context.l10n.implantSlot,
      index: index + 1,
    ),
    SlotIdentifierBooster(:final slotId) => context.l10n.fitAddItemDialogTitleWithIndex(
      slotName: context.l10n.boosterSlot,
      index: slotId,
    ),
  };

  String localizedSlotName(BuildContext context) => switch (this) {
    SlotIdentifierHigh() => context.l10n.highSlot,
    SlotIdentifierMedium() => context.l10n.midSlot,
    SlotIdentifierLow() => context.l10n.lowSlot,
    SlotIdentifierRig() => context.l10n.rigSlot,
    SlotIdentifierSubsystem() => context.l10n.subsystemSlot,
    SlotIdentifierTacticalMode() => context.l10n.tacticalMode,
    SlotIdentifierService() => context.l10n.serviceSlot,
    SlotIdentifierDrone() => context.l10n.drone,
    SlotIdentifierFighter() => context.l10n.fighter,
    SlotIdentifierImplant() => context.l10n.implantSlot,
    SlotIdentifierBooster() => context.l10n.boosterSlot,
  };

  int get baseMarketGroupId => switch (this) {
    SlotIdentifierHigh() => EveConstMarketGroupId.equipment,
    SlotIdentifierMedium() => EveConstMarketGroupId.equipment,
    SlotIdentifierLow() => EveConstMarketGroupId.equipment,
    SlotIdentifierRig() => EveConstMarketGroupId.rig,
    SlotIdentifierSubsystem() => EveConstMarketGroupId.subsystem,
    SlotIdentifierTacticalMode() => 0,
    SlotIdentifierService() => EveConstMarketGroupId.subsystem,
    SlotIdentifierDrone() => EveConstMarketGroupId.drone,
    SlotIdentifierFighter() => EveConstMarketGroupId.fighter,
    SlotIdentifierImplant() => EveConstMarketGroupId.implant,
    SlotIdentifierBooster() => EveConstMarketGroupId.booster,
  };

  bool Function(EveSelectListRoot) validator(WidgetRef ref) {
    final slotsInfo = ref.watch(bundleCollectionGetSlotsProvider);
    if (slotsInfo == null) return (_) => true;

    bool isBaseType(int typeId) {
      final type = ref.read(bundleCollectionGetTypeProvider(typeId));
      return type != null && !type.isDynamicType;
    }

    bool isFighterType(int typeId) {
      final type = ref.read(bundleCollectionGetTypeProvider(typeId));
      return type != null && EveConstGroupId.fighter.contains(type.groupId);
    }

    return switch (this) {
      SlotIdentifierHigh() => (node) => switch (node) {
        EveSelectListRootType(:final typeId) =>
          isBaseType(typeId) && slotsInfo.highSlots.containsKey(typeId),
        _ => true,
      },
      SlotIdentifierMedium() => (node) => switch (node) {
        EveSelectListRootType(:final typeId) =>
          isBaseType(typeId) && slotsInfo.mediumSlots.containsKey(typeId),
        _ => true,
      },
      SlotIdentifierLow() => (node) => switch (node) {
        EveSelectListRootType(:final typeId) =>
          isBaseType(typeId) && slotsInfo.lowSlots.containsKey(typeId),
        _ => true,
      },
      SlotIdentifierRig() => (node) => switch (node) {
        EveSelectListRootType(:final typeId) =>
          isBaseType(typeId) && slotsInfo.rigSlots.containsKey(typeId),
        _ => true,
      },
      SlotIdentifierSubsystem() => (node) => switch (node) {
        EveSelectListRootType(:final typeId) =>
          isBaseType(typeId) && slotsInfo.subsystemSlots.containsKey(typeId),
        _ => true,
      },
      SlotIdentifierTacticalMode() => (_) => true,
      SlotIdentifierService() => (node) => switch (node) {
        EveSelectListRootType(:final typeId) =>
          isBaseType(typeId) && slotsInfo.serviceSlots.containsKey(typeId),
        _ => true,
      },
      SlotIdentifierDrone() => (node) => switch (node) {
        EveSelectListRootType(:final typeId) => isBaseType(typeId) && !isFighterType(typeId),
        _ => true,
      },
      SlotIdentifierFighter() => (node) => switch (node) {
        EveSelectListRootType(:final typeId) => isBaseType(typeId) && isFighterType(typeId),
        _ => true,
      },
      SlotIdentifierImplant() => (node) => switch (node) {
        EveSelectListRootType(:final typeId) =>
          isBaseType(typeId) && slotsInfo.implantSlots[typeId]?.slotIndex == asIndexed + 1,
        _ => true,
      },
      SlotIdentifierBooster() => (node) => switch (node) {
        EveSelectListRootType(:final typeId) =>
          isBaseType(typeId) && slotsInfo.boosterSlots[typeId]?.slotIndex == asIndexed + 1,
        _ => true,
      },
    };
  }
}

final class SlotIdentifierHigh extends SlotIdentifier {
  const SlotIdentifierHigh({required this.index});

  final int index;
}

final class SlotIdentifierMedium extends SlotIdentifier {
  const SlotIdentifierMedium({required this.index});

  final int index;
}

final class SlotIdentifierLow extends SlotIdentifier {
  const SlotIdentifierLow({required this.index});

  final int index;
}

final class SlotIdentifierRig extends SlotIdentifier {
  const SlotIdentifierRig({required this.index});

  final int index;
}

final class SlotIdentifierSubsystem extends SlotIdentifier {
  const SlotIdentifierSubsystem({required this.type});

  final SubsystemType type;
}

final class SlotIdentifierTacticalMode extends SlotIdentifier {
  const SlotIdentifierTacticalMode();
}

final class SlotIdentifierService extends SlotIdentifier {
  const SlotIdentifierService({required this.index});

  final int index;
}

final class SlotIdentifierDrone extends SlotIdentifier {
  const SlotIdentifierDrone({required this.index});

  final int index;
}

final class SlotIdentifierFighter extends SlotIdentifier {
  const SlotIdentifierFighter({required this.index});

  final int index;
}

final class SlotIdentifierImplant extends SlotIdentifier {
  const SlotIdentifierImplant({required this.index});

  final int index;
}

final class SlotIdentifierBooster extends SlotIdentifier {
  const SlotIdentifierBooster({required this.slotId});

  final int slotId;
}
