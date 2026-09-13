part of "../../../page.dart";

class _DroneSlotRow extends ConsumerWidget {
  const _DroneSlotRow({
    required this.fitContext,
    required this.slotIdent,
    required this.slotInfo,
    this.interactionOptions = const FitInteractionOptions(),
  });

  final SlotIdentifierDrone slotIdent;
  final _ItemSlotInfo slotInfo;
  final FitContext fitContext;
  final FitInteractionOptions interactionOptions;

  List<TileAction> _buildStartActions(BuildContext context, WidgetRef ref) {
    final actions = <TileAction>[
      if (fitContext.fit.body.drones.getOrNull(slotIdent.index)?.quantity != 1)
        TileAction(
          onPressed: (_) => _handleSetAmount(context, ref, 1),
          backgroundColor: Colors.green.shade200,
          foregroundColor: Colors.black,
          label: "x1",
        ),
      if (fitContext.fit.body.drones.getOrNull(slotIdent.index)?.quantity != 5)
        TileAction(
          onPressed: (_) => _handleSetAmount(context, ref, 5),
          backgroundColor: Colors.green.shade400,
          foregroundColor: Colors.white,
          label: "x5",
        ),
    ];

    final dynamicItem = fitContext.dynamicItemFor(slotInfo.slot.itemId);
    if (dynamicItem != null) {
      actions
        ..add(
          TileAction(
            onPressed: (_) => fitContext.fitWrapper.revertDroneFromDynamic(slotIdent.index),
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
    } else if (_availableDynamicModifierTypeIds(ref).isNotEmpty) {
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

    if (dynamicItem != null || _availableDynamicModifierTypeIds(ref).isNotEmpty) {
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

    return actions;
  }

  List<TileAction> _buildEndActions(BuildContext context, WidgetRef ref) => <TileAction>[
    if ((fitContext.fit.body.drones.getOrNull(slotIdent.index)?.quantity ?? 0) > 1)
      TileAction(
        onPressed: (_) => _handleAddAmount(context, ref, -1),
        autoClose: false,
        backgroundColor: Colors.red.shade400,
        foregroundColor: Colors.white,
        label: "-1",
      ),
    TileAction(
      onPressed: (_) => _handleAddAmount(context, ref, 1),
      autoClose: false,
      backgroundColor: Colors.green.shade400,
      foregroundColor: Colors.black,
      label: "+1",
    ),
    if (fitContext.dynamicItemFor(slotInfo.slot.itemId) != null)
      TileAction(
        onPressed: (_) => fitContext.fitWrapper.revertAllSameDynamicDrones(slotIdent.index),
        backgroundColor: Colors.grey,
        foregroundColor: Colors.white,
        icon: Icons.cyclone_outlined,
        label: context.l10n.fitActionRevertAllDynamic,
        group: _SlotActionGroup.abyss,
      ),
    TileAction(
      onPressed: (_) => _handleRemoveDrone(context, ref),
      backgroundColor: colorActionDelete,
      foregroundColor: Colors.white,
      icon: Icons.delete,
      label: context.l10n.delete,
    ),
  ];

  List<TileAction> _buildRecoveryActions(BuildContext context, WidgetRef ref) => <TileAction>[
    TileAction(
      onPressed: (_) => _handleRemoveDrone(context, ref),
      backgroundColor: colorActionDelete,
      foregroundColor: Colors.white,
      icon: Icons.delete,
      label: context.l10n.delete,
    ),
  ];

  Future<void> _handleSetAmount(BuildContext context, WidgetRef ref, int amount) async {
    await fitContext.fitWrapper.changeDroneAmount(slotIdent.index, amount);
  }

  Future<void> _handleAddAmount(BuildContext context, WidgetRef ref, int diff) async {
    await fitContext.fitWrapper.changeDroneAmountBy(slotIdent.index, diff);
  }

  Future<void> _handleRemoveDrone(BuildContext context, WidgetRef ref) async {
    await fitContext.fitWrapper.removeDrone(slotIdent.index);
  }

  List<int> _availableDynamicModifierTypeIds(WidgetRef ref) {
    final originTypeId = fitContext.resolveOriginTypeId(slotInfo.slot.itemId);
    if (originTypeId == null) return const [];

    final collection = ref.read(repoCollectionProvider);
    return collection?.getDynamicTypeOptions(originTypeId)?.modifierTypeIds.toList() ?? const [];
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

    await fitContext.fitWrapper.convertDroneToDynamic(slotIdent.index, modifierTypeId);
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

    await fitContext.fitWrapper.mutateAllSameOriginDrones(slotIdent.index, modifierTypeId);
  }

  Widget _buildRecoveryRow(BuildContext context, WidgetRef ref, String title) {
    final quantity = fitContext.fit.body.drones.getOrNull(slotIdent.index)?.quantity ?? 0;
    final recoveryActions = _buildRecoveryActions(context, ref);
    final content = ListTile(title: Text(title), trailing: Text("x $quantity"));

    if (!interactionOptions.allowMutations) return content;

    return Slidable(
      endActionPane: buildTileActionPane(recoveryActions, overflowFirst: true),
      child: SlidableEdgeZone(
        child: TileSecondaryActionRegion(actions: recoveryActions, child: content),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemId = slotInfo.slot.itemId;
    final displayTypeId = fitContext.resolveDisplayTypeId(itemId);
    if (displayTypeId == null) {
      return _buildRecoveryRow(
        context,
        ref,
        context.l10n.fitUnknownItemWithIdAtSlot(itemId: itemId.asId, slot: slotInfo.index),
      );
    }

    final typeDef = ref.watch(repoCollectionProvider.select((c) => c?.getType(displayTypeId)));
    if (typeDef == null) {
      return _buildRecoveryRow(
        context,
        ref,
        context.l10n.fitUnknownItemWithIdAtSlot(itemId: displayTypeId, slot: slotInfo.index),
      );
    }

    final metaGroupIcon = ref.watch(
      repoCollectionProvider.select((c) => c?.getMetaGroup(typeDef.metaGroupId)?.icon),
    );

    final startActions = _buildStartActions(context, ref);
    final endActions = _buildEndActions(context, ref);

    final quantity = fitContext.fit.body.drones.getOrNull(slotIdent.index)?.quantity ?? 0;

    final droneItems =
        fitContext.emulated?.modules
            .where(
              (item) => switch (item.slot.slotType) {
                native.OutSlotType_DroneBay(:final groupId) => groupId == slotIdent.index,
                _ => false,
              },
            )
            .toList() ??
        const <native.Item>[];
    final representative = droneItems.isEmpty ? null : droneItems.first;
    final isActive =
        fitContext.fit.body.drones.getOrNull(slotIdent.index)?.state == FitItemState.active;
    final dps = representative?.getAttribute(EveConstExtendedAttrID.damagePerSecondWithoutReload);
    final volley = representative?.getAttribute(EveConstExtendedAttrID.damageVolley);
    final dpsText = !isActive || dps == null || volley == null
        ? null
        : Text(
            "$quantity x "
            "${dps.toStringAsFixed(1)}/s = "
            "${(dps * quantity).toStringAsFixed(1)}/s\n"
            "$quantity x "
            "${volley.toStringAsFixed(1)} = "
            "${(volley * quantity).toStringAsFixed(1)}",
          );

    final content = ListTile(
      leading: StateIcon.rect(
        state: slotInfo.state.toEfa(),
        onTap: interactionOptions.allowStateToggle
            ? () => fitContext.fitWrapper.toggleSlot(slotIdent, ref)
            : null,
        child: EveIcon(icon: typeDef.icon, overlayIcon: metaGroupIcon, size: 35),
      ),
      title: LocalizedTypeName(typeId: displayTypeId),
      subtitle: dpsText,
      trailing: Text("x $quantity"),
      onTap: interactionOptions.allowInspect
          ? () => showItemDetailPage(
              context,
              typeId: displayTypeId,
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
              typeId: displayTypeId,
              fitReference: ItemDetailFitReference.module(
                fitId: fitContext.fitId,
                slotType: slotInfo.type,
                index: slotInfo.index,
              ),
            )
          : null,
    );

    if (!interactionOptions.allowMutations) return content;

    return Slidable(
      startActionPane: buildTileActionPane(startActions),
      endActionPane: buildTileActionPane(endActions, overflowFirst: true),
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
}
