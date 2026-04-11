part of "../../../page.dart";

// TODO(dynamic-item-conversion): Re-enable after conversion parity work lands.
const bool _dynamicItemConversionEnabled = false;

class _AnySlotRow extends StatelessWidget {
  const _AnySlotRow({
    required this.fitContext,
    required this.slotIdent,
    required this.slotInfo,
    this.interactionOptions = const FitInteractionOptions(),
  });

  final FitContext fitContext;
  final SlotIdentifier slotIdent;
  final SlotInfo slotInfo;
  final FitInteractionOptions interactionOptions;

  @override
  Widget build(BuildContext context) => switch (slotInfo) {
    final _EmptySlotInfo emptySlotInfo => _EmptySlotRow(
      slotIdent: slotIdent,
      slotInfo: emptySlotInfo,
      fitContext: fitContext,
      interactionOptions: interactionOptions,
    ),
    final _ItemSlotInfo itemSlotInfo => _SlotRow(
      fitContext: fitContext,
      slotIdent: slotIdent,
      slotInfo: itemSlotInfo,
      interactionOptions: interactionOptions,
    ),
  };
}

class _SlotRow extends ConsumerWidget {
  const _SlotRow({
    required this.fitContext,
    required this.slotIdent,
    required this.slotInfo,
    required this.interactionOptions,
  });

  final FitContext fitContext;
  final SlotIdentifier slotIdent;
  final _ItemSlotInfo slotInfo;
  final FitInteractionOptions interactionOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (slotIdent) {
      case final SlotIdentifierTacticalMode mode:
        return _TacticalModeSlotRow(
          fitContext: fitContext,
          slotIdent: mode,
          slotInfo: slotInfo,
          interactionOptions: interactionOptions,
        );

      case final SlotIdentifierSubsystem subsystem:
        return _SubsystemSlotRow(
          fitContext: fitContext,
          slotIdent: subsystem,
          slotInfo: slotInfo,
          interactionOptions: interactionOptions,
        );

      case final SlotIdentifierDrone drone:
        return _DroneSlotRow(
          fitContext: fitContext,
          slotIdent: drone,
          slotInfo: slotInfo,
          interactionOptions: interactionOptions,
        );

      case final SlotIdentifierFighter fighter:
        return _FighterSlotRow(
          fitContext: fitContext,
          slotIdent: fighter,
          slotInfo: slotInfo,
          interactionOptions: interactionOptions,
        );

      default:
        final displayTypeId = fitContext.resolveDisplayTypeId(slotInfo.slot.itemId);
        if (displayTypeId == null) {
          return ListTile(
            title: Text("Unknown Item ${slotInfo.slot.itemId.asId} at slot ${slotInfo.index}"),
          );
        }

        final type = ref.watch(bundleCollectionGetTypeProvider(displayTypeId));
        if (type == null) {
          return ListTile(title: Text("Unknown Item $displayTypeId at slot ${slotInfo.index}"));
        }

        final typeName = ref.watch(localizationProvider(type.typeName.id).select((t) => t ?? ""));

        return _SlotRowDisplay(
          fitContext: fitContext,
          slotIdent: slotIdent,
          slotInfo: slotInfo,
          itemType: type,
          typeName: typeName,
          interactionOptions: interactionOptions,
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
    required this.interactionOptions,
  });

  final FitContext fitContext;
  final SlotIdentifier slotIdent;
  final _ItemSlotInfo slotInfo;
  final pb_types.Type itemType;
  final String typeName;
  final FitInteractionOptions interactionOptions;

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
          InkWell(
            onTap: interactionOptions.allowInspect
                ? () => showItemDetailPage(
                    context,
                    typeId: chargeId,
                    fitReference: ItemDetailFitReference.module(
                      fitId: fitContext.fitId,
                      slotType: slotInfo.type,
                      index: slotInfo.index,
                      inspectCharge: true,
                    ),
                  )
                : null,
            onLongPress: interactionOptions.allowInspect
                ? () => showItemDetailPage(
                    context,
                    typeId: chargeId,
                    fitReference: ItemDetailFitReference.module(
                      fitId: fitContext.fitId,
                      slotType: slotInfo.type,
                      index: slotInfo.index,
                      inspectCharge: true,
                    ),
                  )
                : null,
            child: Row(
              children: [
                EveIcon(icon: chargeType.icon, size: 18),
                const SizedBox(width: 4),
                Text(chargeName, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        );
      }
    }

    final startActions = _buildStartActions(context, ref);
    final endActions = _buildEndActions(context, ref);

    final metaGroupIcon = ref.watch(
      bundleCollectionGetMetaGroupProvider(itemType.metaGroupId).select((t) => t?.icon),
    );

    final content = ListTile(
      leading: StateIcon.rect(
        state: slotInfo.state,
        onTap: interactionOptions.allowStateToggle ? () => _handleToggleState(ref) : null,
        child: EveIcon(icon: itemType.icon, overlayIcon: metaGroupIcon, size: 35),
      ),
      title: Text(typeName),
      subtitle: subtitleWidgets.isEmpty
          ? null
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: subtitleWidgets),
      onTap: interactionOptions.allowInspect
          ? () => showItemDetailPage(
              context,
              typeId: itemType.typeId,
              fitReference: ItemDetailFitReference.module(
                fitId: fitContext.fitId,
                slotType: slotInfo.type,
                index: slotInfo.index,
              ),
            )
          : null,
      onLongPress: interactionOptions.allowInspect
          ? () => showItemDetailPage(
              context,
              typeId: itemType.typeId,
              fitReference: ItemDetailFitReference.module(
                fitId: fitContext.fitId,
                slotType: slotInfo.type,
                index: slotInfo.index,
              ),
            )
          : null,
    );

    if (!interactionOptions.allowMutations) {
      return content;
    }

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
      child: content,
    );
  }

  List<SlidableAction> _buildStartActions(BuildContext context, WidgetRef ref) {
    final actions = <SlidableAction>[];
    final isDynamic = fitContext.dynamicItemFor(slotInfo.slot.itemId) != null;

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

    if (isDynamic) {
      actions.add(
        SlidableAction(
          onPressed: (_) => fitContext.fitWrapper.revertSlotFromDynamic(slotIdent),
          backgroundColor: Colors.grey,
          foregroundColor: Colors.white,
          icon: Icons.cyclone_outlined,
          label: context.l10n.dynamicRevert,
          padding: .zero,
        ),
      );
    } else if (_supportsDynamicItemConversion() &&
        _availableDynamicModifierTypeIds(ref).isNotEmpty) {
      actions.add(
        SlidableAction(
          onPressed: (_) => _handleConvertToDynamic(context, ref),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          icon: Icons.cyclone_outlined,
          label: context.l10n.dynamicConvert,
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
    final originTypeId = fitContext.resolveOriginTypeId(slotInfo.slot.itemId);
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

  bool _supportsDynamicItemConversion() => _dynamicItemConversionEnabled && _canCopy();

  List<int> _availableDynamicModifierTypeIds(WidgetRef ref) {
    final originTypeId = fitContext.resolveOriginTypeId(slotInfo.slot.itemId);
    if (originTypeId == null) return const [];

    final collection = ref.read(bundleCollectionProvider);
    return collection?.getDynamicTypeOptions(originTypeId)?.modifierTypeIds.toList() ?? const [];
  }

  Future<void> _handleToggleState(WidgetRef ref) async {
    await fitContext.fitWrapper.toggleSlot(slotIdent, ref);
  }

  Future<void> _handleCopy(BuildContext context, WidgetRef ref) async {
    await fitContext.fitWrapper.copySlotToNext(slotIdent);
  }

  Future<void> _handleConvertToDynamic(BuildContext context, WidgetRef ref) async {
    final modifierTypeIds = _availableDynamicModifierTypeIds(ref);
    if (modifierTypeIds.isEmpty) return;

    final modifierTypeId = await showDialog<int>(
      context: context,
      builder: (context) => AppDialog(
        title: context.l10n.dynamicSelectTitle,
        content: _DynamicModifierDialog(modifierTypeIds: modifierTypeIds),
      ),
    );
    if (modifierTypeId == null) return;

    await fitContext.fitWrapper.convertSlotToDynamic(slotIdent, modifierTypeId, ref);
  }

  Future<void> _handleSetCharge(BuildContext context, WidgetRef ref) async {
    final originTypeId = fitContext.resolveOriginTypeId(slotInfo.slot.itemId);
    if (originTypeId == null) return;

    final slots = ref.read(bundleCollectionGetSlotsProvider);
    if (slots == null) return;

    final chargeGroups = switch (slotIdent) {
      SlotIdentifierHigh _ => slots.highSlots[originTypeId]?.chargeGroups,
      SlotIdentifierMedium _ => slots.mediumSlots[originTypeId]?.chargeGroups,
      SlotIdentifierLow _ => slots.lowSlots[originTypeId]?.chargeGroups,
      _ => null,
    };
    if (chargeGroups == null || chargeGroups.isEmpty) return;

    final chargeTypeId = await showAddChargeDialog(context: context, chargeGroups: chargeGroups);
    if (chargeTypeId == null) return;

    await fitContext.fitWrapper.setSlotCharge(slotIdent, chargeTypeId);
  }
}

class _DynamicModifierDialog extends ConsumerWidget {
  const _DynamicModifierDialog({required this.modifierTypeIds});

  final List<int> modifierTypeIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
    width: double.maxFinite,
    child: ListView.builder(
      shrinkWrap: true,
      itemCount: modifierTypeIds.length,
      itemBuilder: (context, index) {
        final modifierTypeId = modifierTypeIds[index];
        final type = ref.watch(bundleCollectionGetTypeProvider(modifierTypeId));
        if (type == null) {
          return ListTile(title: Text("Unknown Type $modifierTypeId"));
        }

        final typeName = ref.watch(localizationProvider(type.typeName.id).select((t) => t ?? ""));

        return ListTile(
          onTap: () => Navigator.of(context).pop(modifierTypeId),
          leading: EveIcon(icon: type.icon, size: 32),
          title: Text(typeName),
        );
      },
    ),
  );
}
