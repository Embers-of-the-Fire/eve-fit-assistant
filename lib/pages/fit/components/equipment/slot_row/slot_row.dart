part of "../../../page.dart";

class _AnySlotRow extends StatelessWidget {
  const _AnySlotRow({required this.fitContext, required this.slotIdent, required this.slotInfo});

  final FitContext fitContext;
  final SlotIdentifier slotIdent;
  final SlotInfo slotInfo;

  @override
  Widget build(BuildContext context) => slotInfo.when(
    empty: (index) => _EmptySlotRow(
      slotIdent: slotIdent,
      slotInfo: _EmptySlotInfo(index: index),
      fitContext: fitContext,
    ),
    item: (state, type, index, slot) => _SlotRow(
      fitContext: fitContext,
      slotIdent: slotIdent,
      slotInfo: _ItemSlotInfo(state: state, type: type, index: index, slot: slot),
    ),
  );
}

class _SlotRow extends ConsumerWidget {
  const _SlotRow({required this.fitContext, required this.slotIdent, required this.slotInfo});

  final FitContext fitContext;
  final SlotIdentifier slotIdent;
  final _ItemSlotInfo slotInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (slotIdent) {
      case final SlotIdentifierTacticalMode mode:
        return _TacticalModeSlotRow(fitContext: fitContext, slotIdent: mode, slotInfo: slotInfo);

      case final SlotIdentifierSubsystem subsystem:
        return _SubsystemSlotRow(fitContext: fitContext, slotIdent: subsystem, slotInfo: slotInfo);

      case final SlotIdentifierDrone drone:
        return _DroneSlotRow(fitContext: fitContext, slotIdent: drone, slotInfo: slotInfo);

      default:
        final itemId = slotInfo.slot.itemId;
        if (itemId is! FitStorageItemIdItem) {
          return ListTile(
            title: Text(
              "${slotInfo.state} at ${slotInfo.index}[${slotInfo.slot}]: ${slotInfo.type}",
            ),
          );
        }

        final type = ref.watch(bundleCollectionGetTypeProvider(itemId.asId));
        if (type == null) {
          return ListTile(title: Text("Unknown Item ${itemId.asId} at slot ${slotInfo.index}"));
        }

        final typeName = ref.watch(localizationProvider(type.typeName.id).select((t) => t ?? ""));

        return _SlotRowDisplay(
          fitContext: fitContext,
          slotIdent: slotIdent,
          slotInfo: slotInfo,
          itemType: type,
          typeName: typeName,
        );
    }
  }
}

class _SlotRowDisplay extends ConsumerWidget {
  const _SlotRowDisplay({
    required this.fitContext,
    required this.slotIdent,
    required this.slotInfo,
    required this.itemType,
    required this.typeName,
  });

  final FitContext fitContext;
  final SlotIdentifier slotIdent;
  final _ItemSlotInfo slotInfo;
  final pb_types.Type itemType;
  final String typeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitleWidgets = <Widget>[];

    if (slotInfo.slot.charge.isSome()) {
      final chargeId = slotInfo.slot.charge.toNullable()!.typeId;
      final chargeType = ref.watch(bundleCollectionGetTypeProvider(chargeId));
      if (chargeType != null) {
        final chargeName = ref.watch(
          localizationProvider(chargeType.typeName.id).select((t) => t ?? ""),
        );
        subtitleWidgets.add(
          Row(
            children: [
              EveIcon(icon: chargeType.icon, size: 18),
              const SizedBox(width: 4),
              Text(chargeName, style: const TextStyle(fontSize: 14)),
            ],
          ),
        );
      }
    }

    final startActions = _buildStartActions(context, ref);
    final endActions = _buildEndActions(context, ref);

    final metaGroupIcon = ref.watch(
      bundleCollectionGetMetaGroupProvider(itemType.metaGroupId).select((t) => t?.icon),
    );

    return Slidable(
      startActionPane: startActions.isEmpty
          ? null
          : ActionPane(
              extentRatio: 0.15 * startActions.length,
              motion: const StretchMotion(),
              children: startActions,
            ),
      endActionPane: endActions.isEmpty
          ? null
          : ActionPane(
              extentRatio: 0.15 * endActions.length,
              motion: const StretchMotion(),
              children: endActions,
            ),
      child: ListTile(
        leading: StateIcon.rect(
          state: slotInfo.state,
          onTap: () => _handleToggleState(ref),
          child: EveIcon(icon: itemType.icon, overlayIcon: metaGroupIcon, size: 35),
        ),
        title: Text(typeName),
        subtitle: subtitleWidgets.isEmpty
            ? null
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: subtitleWidgets),
      ),
    );
  }

  List<SlidableAction> _buildStartActions(BuildContext context, WidgetRef ref) {
    final actions = <SlidableAction>[];

    if (_canCopy()) {
      actions.add(
        SlidableAction(
          onPressed: (_) => _handleCopy(context, ref),
          autoClose: false,
          icon: Icons.copy,
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.black,
          label: context.l10n.copy,
          padding: .zero,
        ),
      );
    }

    if (_canHaveCharge(ref)) {
      actions.add(
        SlidableAction(
          onPressed: (_) => _handleSetCharge(context, ref),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          icon: Icons.battery_charging_full,
          label: context.l10n.charge,
          padding: .zero,
        ),
      );
    }

    return actions;
  }

  List<SlidableAction> _buildEndActions(BuildContext context, WidgetRef ref) {
    final actions = <SlidableAction>[];

    if (slotInfo.slot.charge.isSome() && _canHaveCharge(ref)) {
      actions.add(
        SlidableAction(
          onPressed: (_) => fitContext.fitWrapper.removeSlotCharge(slotIdent),
          backgroundColor: Colors.grey,
          foregroundColor: Colors.white,
          icon: Icons.cancel,
          label: context.l10n.charge,
          padding: .zero,
        ),
      );
    }

    actions.add(
      SlidableAction(
        onPressed: (_) => fitContext.fitWrapper.removeSlotAdjusted(slotIdent, ref),
        backgroundColor: colorActionDelete,
        foregroundColor: Colors.white,
        icon: Icons.delete,
        label: context.l10n.delete,
        padding: .zero,
      ),
    );

    return actions;
  }

  bool _canHaveCharge(WidgetRef ref) {
    final originTypeId = slotInfo.slot.itemId.map(
      item: (item) => item.id,
      dynamic: (dyn) {
        final dynItem = fitContext.fit.dynamicRegistry.dynamicItems.get(dyn.dynamicId);
        return dynItem?.originTypeId;
      },
    );
    if (originTypeId == null) return false;

    final slots = ref.read(bundleCollectionGetSlotsProvider);
    if (slots == null) return false;
    return switch (slotIdent) {
      SlotIdentifierHigh _ => slots.highSlots[originTypeId]?.chargeGroups.isNotEmpty ?? false,
      SlotIdentifierMedium _ => slots.mediumSlots[originTypeId]?.chargeGroups.isNotEmpty ?? false,
      SlotIdentifierLow _ => slots.lowSlots[originTypeId]?.chargeGroups.isNotEmpty ?? false,
      _ => false,
    };
  }

  bool _canCopy() =>
      slotIdent is SlotIdentifierHigh ||
      slotIdent is SlotIdentifierMedium ||
      slotIdent is SlotIdentifierLow ||
      slotIdent is SlotIdentifierRig;

  Future<void> _handleToggleState(WidgetRef ref) async {
    await fitContext.fitWrapper.toggleSlot(slotIdent, ref);
  }

  Future<void> _handleCopy(BuildContext context, WidgetRef ref) async {
    await fitContext.fitWrapper.copySlotToNext(slotIdent);
  }

  Future<void> _handleSetCharge(BuildContext context, WidgetRef ref) async {
    // TODO: Implement charge selection dialog
    // Need to filter compatible charges based on module type
  }
}
