part of "../../../page.dart";

const bool _dynamicItemConversionEnabled = true;

/// Visual groups of a slot tile's dropdown actions, in dropdown order.
enum _SlotActionGroup { action, charge, abyss }

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
            title: Text(
              context.l10n.fitUnknownItemWithIdAtSlot(
                itemId: slotInfo.slot.itemId.asId,
                slot: slotInfo.index,
              ),
            ),
          );
        }

        final type = ref.watch(repoCollectionProvider.select((c) => c?.getType(displayTypeId)));
        if (type == null) {
          return ListTile(
            title: Text(
              context.l10n.fitUnknownItemWithIdAtSlot(itemId: displayTypeId, slot: slotInfo.index),
            ),
          );
        }

        final locale = ref.watch(localeProvider).name;
        final typeName = watchLocalizedName(ref, id: type.typeName.id, locale: locale) ?? "";

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

    final moduleItem = _resolveNativeModuleItem(fitContext, slotInfo);

    if (slotInfo.slot.charge.isSome()) {
      final chargeId = slotInfo.slot.charge.toNullable()!.typeId;
      final chargeType = ref.watch(repoCollectionProvider.select((c) => c?.getType(chargeId)));
      if (chargeType != null) {
        final locale = ref.watch(localeProvider).name;
        final chargeName =
            watchLocalizedName(ref, id: chargeType.typeName.id, locale: locale) ?? "";
        final chargeAmount = moduleItem?.getAttribute(EveConstExtendedAttrID.chargeAmount) ?? 0;
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
                if (chargeAmount > 0) ...[
                  Text("${chargeAmount.round()}× ", style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                ],
                EveIcon(icon: chargeType.icon, size: 18),
                const SizedBox(width: 4),
                Text(chargeName, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        );
      }
    }

    if (moduleItem != null) {
      final relatedValues = collectSlotRelatedValues(moduleItem);
      if (relatedValues.isNotEmpty) {
        subtitleWidgets.add(_SlotRelatedValuesRow(segments: relatedValues));
      }
    }

    final startActions = _buildStartActions(context, ref);
    final endActions = _buildEndActions(context, ref);

    final metaGroupIcon = ref.watch(
      repoCollectionProvider.select((c) => c?.getMetaGroup(itemType.metaGroupId)?.icon),
    );
    final slotIssues = _collectFitIssuesForSlot(context, ref, fitContext, slotIdent);

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
      trailing: slotIssues.isEmpty ? null : _FitIssueTrigger(issues: slotIssues),
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
      startActionPane: buildTileActionPane(startActions),
      endActionPane: buildTileActionPane(endActions),
      child: SlidableEdgeZone(
        child: TileSecondaryActionRegion(
          actions: flattenTileActionGroups([
            ...startActions,
            ...endActions,
          ], _SlotActionGroup.values),
          child: content,
        ),
      ),
    );
  }

  List<TileAction> _buildStartActions(BuildContext context, WidgetRef ref) {
    final actions = <TileAction>[];
    final isDynamic = fitContext.dynamicItemFor(slotInfo.slot.itemId) != null;

    if (_canHaveCharge(ref)) {
      actions
        ..add(
          TileAction(
            onPressed: (_) => _handleSetCharge(context, ref),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            icon: Icons.battery_charging_full,
            label: context.l10n.charge,
            group: _SlotActionGroup.charge,
          ),
        )
        ..add(
          TileAction(
            onPressed: (_) => _handleChargeAll(context, ref),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            icon: Icons.battery_charging_full,
            label: context.l10n.fitActionChargeAll,
            group: _SlotActionGroup.charge,
          ),
        );
    }

    if (isDynamic) {
      actions
        ..add(
          TileAction(
            onPressed: (_) => fitContext.fitWrapper.revertSlotFromDynamic(slotIdent),
            backgroundColor: Colors.grey,
            foregroundColor: Colors.white,
            icon: Icons.cyclone_outlined,
            label: context.l10n.dynamicRevert,
            group: _SlotActionGroup.abyss,
          ),
        )
        ..add(
          TileAction(
            onPressed: (_) => _handleMutateRandom(context, ref),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            icon: Icons.casino_outlined,
            label: context.l10n.fitActionMutateRandom,
            group: _SlotActionGroup.abyss,
          ),
        );
    } else if (_supportsDynamicItemConversion() &&
        _availableDynamicModifierTypeIds(ref).isNotEmpty) {
      actions.add(
        TileAction(
          onPressed: (_) => _handleConvertToDynamic(context, ref),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          icon: Icons.cyclone_outlined,
          label: context.l10n.dynamicConvert,
          group: _SlotActionGroup.abyss,
        ),
      );
    }

    if (_canMutateAll(ref)) {
      actions.add(
        TileAction(
          onPressed: (_) => _handleMutateAll(context, ref),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          icon: Icons.casino_outlined,
          label: context.l10n.fitActionMutateRandomAll,
          group: _SlotActionGroup.abyss,
        ),
      );
    }

    if (_canCopy()) {
      actions
        ..add(
          TileAction(
            onPressed: (_) => _handleCopy(context, ref),
            autoClose: false,
            icon: Icons.copy,
            backgroundColor: Colors.grey.shade200,
            foregroundColor: Colors.black,
            label: context.l10n.copy,
            group: _SlotActionGroup.action,
          ),
        )
        ..add(
          TileAction(
            onPressed: (_) => fitContext.fitWrapper.fillSlotsFromSlot(slotIdent),
            backgroundColor: Colors.grey.shade200,
            foregroundColor: Colors.black,
            icon: Icons.copy_all,
            label: context.l10n.fitActionFillAll,
            group: _SlotActionGroup.action,
          ),
        );
    }

    return actions;
  }

  List<TileAction> _buildEndActions(BuildContext context, WidgetRef ref) {
    final actions = <TileAction>[];

    if (slotInfo.slot.charge.isSome() && _canHaveCharge(ref)) {
      actions.add(
        TileAction(
          onPressed: (_) => fitContext.fitWrapper.removeSlotCharge(slotIdent),
          backgroundColor: Colors.grey,
          foregroundColor: Colors.white,
          icon: Icons.cancel,
          label: context.l10n.charge,
          group: _SlotActionGroup.charge,
        ),
      );
    }

    if (slotInfo.slot.charge.isSome() && _canHaveCharge(ref)) {
      actions.add(
        TileAction(
          onPressed: (_) => fitContext.fitWrapper.removeChargesForSameType(slotIdent),
          backgroundColor: Colors.grey,
          foregroundColor: Colors.white,
          icon: Icons.cancel,
          label: context.l10n.fitActionRemoveAllCharges,
          group: _SlotActionGroup.charge,
        ),
      );
    }

    if (fitContext.dynamicItemFor(slotInfo.slot.itemId) != null) {
      actions.add(
        TileAction(
          onPressed: (_) => fitContext.fitWrapper.revertAllSameDynamic(slotIdent),
          backgroundColor: Colors.grey,
          foregroundColor: Colors.white,
          icon: Icons.cyclone_outlined,
          label: context.l10n.fitActionRevertAllDynamic,
          group: _SlotActionGroup.abyss,
        ),
      );
    }

    actions.add(
      TileAction(
        onPressed: (_) => fitContext.fitWrapper.removeSlotAdjusted(slotIdent, ref),
        backgroundColor: colorActionDelete,
        foregroundColor: Colors.white,
        icon: Icons.delete,
        label: context.l10n.delete,
        group: _SlotActionGroup.action,
      ),
    );

    if (_canCopy()) {
      actions.add(
        TileAction(
          onPressed: (_) => fitContext.fitWrapper.removeAllSlotsOfType(slotIdent),
          backgroundColor: colorActionDelete,
          foregroundColor: Colors.white,
          icon: Icons.delete_sweep,
          label: context.l10n.fitActionRemoveAll,
          group: _SlotActionGroup.action,
        ),
      );
    }

    return actions;
  }

  bool _canHaveCharge(WidgetRef ref) {
    final originTypeId = fitContext.resolveOriginTypeId(slotInfo.slot.itemId);
    if (originTypeId == null) return false;

    final slots = ref.read(repoCollectionProvider)?.slots;
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

  bool _canMutateAll(WidgetRef ref) {
    if (!_supportsDynamicItemConversion()) return false;
    if (fitContext.dynamicItemFor(slotInfo.slot.itemId) != null) return true;
    return _availableDynamicModifierTypeIds(ref).isNotEmpty;
  }

  List<int> _availableDynamicModifierTypeIds(WidgetRef ref) {
    final originTypeId = fitContext.resolveOriginTypeId(slotInfo.slot.itemId);
    if (originTypeId == null) return const [];

    final collection = ref.read(repoCollectionProvider);
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

  List<int>? _chargeGroups(WidgetRef ref) {
    final originTypeId = fitContext.resolveOriginTypeId(slotInfo.slot.itemId);
    if (originTypeId == null) return null;

    final slots = ref.read(repoCollectionProvider)?.slots;
    if (slots == null) return null;

    return switch (slotIdent) {
      SlotIdentifierHigh _ => slots.highSlots[originTypeId]?.chargeGroups,
      SlotIdentifierMedium _ => slots.mediumSlots[originTypeId]?.chargeGroups,
      SlotIdentifierLow _ => slots.lowSlots[originTypeId]?.chargeGroups,
      _ => null,
    };
  }

  Future<void> _handleMutateRandom(BuildContext context, WidgetRef ref) async {
    final dynamicItem = fitContext.dynamicItemFor(slotInfo.slot.itemId);
    if (dynamicItem == null) return;
    await fitContext.fitWrapper.randomizeDynamicAttributes(dynamicItem.dynamicItemId);
  }

  Future<void> _handleMutateAll(BuildContext context, WidgetRef ref) async {
    var modifierTypeId = fitContext.dynamicItemFor(slotInfo.slot.itemId)?.modifierTypeId;
    if (modifierTypeId == null) {
      final modifierTypeIds = _availableDynamicModifierTypeIds(ref);
      if (modifierTypeIds.isEmpty) return;

      modifierTypeId = await showDialog<int>(
        context: context,
        builder: (context) => AppDialog(
          title: context.l10n.dynamicSelectTitle,
          content: _DynamicModifierDialog(modifierTypeIds: modifierTypeIds),
        ),
      );
      if (modifierTypeId == null) return;
    }

    await fitContext.fitWrapper.mutateAllSameOrigin(slotIdent, modifierTypeId);
  }

  Future<void> _handleChargeAll(BuildContext context, WidgetRef ref) async {
    var chargeTypeId = slotInfo.slot.charge.toNullable()?.typeId;
    if (chargeTypeId == null) {
      final chargeGroups = _chargeGroups(ref);
      if (chargeGroups == null || chargeGroups.isEmpty) return;

      chargeTypeId = await showAddChargeDialog(context: context, chargeGroups: chargeGroups);
      if (chargeTypeId == null) return;
    }

    await fitContext.fitWrapper.setChargeForSameType(slotIdent, chargeTypeId);
  }

  Future<void> _handleSetCharge(BuildContext context, WidgetRef ref) async {
    final chargeGroups = _chargeGroups(ref);
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
        final type = ref.watch(repoCollectionProvider.select((c) => c?.getType(modifierTypeId)));
        if (type == null) {
          return ListTile(
            title: Text(context.l10n.fallbackTypeUnavailable(typeId: modifierTypeId)),
          );
        }

        final locale = ref.watch(localeProvider).name;
        final typeName = watchLocalizedName(ref, id: type.typeName.id, locale: locale) ?? "";

        return ListTile(
          onTap: () => Navigator.of(context).pop(modifierTypeId),
          leading: EveIcon(icon: type.icon, size: 32),
          title: Text(typeName),
        );
      },
    ),
  );
}
