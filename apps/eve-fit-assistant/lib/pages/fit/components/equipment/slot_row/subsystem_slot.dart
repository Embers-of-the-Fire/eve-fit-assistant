part of "../../../page.dart";

class _SubsystemSlotRow extends ConsumerWidget {
  const _SubsystemSlotRow({
    required this.fitContext,
    required this.slotIdent,
    required this.slotInfo,
    required this.interactionOptions,
  });

  final SlotIdentifierSubsystem slotIdent;
  final _ItemSlotInfo slotInfo;
  final FitContext fitContext;
  final FitInteractionOptions interactionOptions;

  Future<void> _handleRemoveSubsystem(WidgetRef ref) =>
      fitContext.fitWrapper.removeSlotAdjusted(slotIdent, ref);

  Future<void> _handleReplaceSubsystem(BuildContext context, WidgetRef ref) async {
    final typeId = await showAddItemDialog(
      context: context,
      title: slotIdent.localizedAddItemDialogTitle(context),
      initialMarketGroupId: slotIdent.baseMarketGroupId,
      validator: _buildSubsystemValidator(
        ref: ref,
        fitContext: fitContext,
        slotIdent: slotIdent,
        type: slotIdent.type,
      ),
    );
    if (typeId == null) return;
    await fitContext.fitWrapper.equipSlot(slotIdent, typeId, ref);
  }

  List<TileAction> _buildReplaceActions(BuildContext context, WidgetRef ref) => [
    TileAction(
      onPressed: (_) => _handleReplaceSubsystem(context, ref),
      backgroundColor: Colors.grey.shade200,
      foregroundColor: Colors.black,
      icon: Icons.change_circle_outlined,
      label: context.l10n.edit,
    ),
  ];

  List<TileAction> _buildRemoveActions(BuildContext context, WidgetRef ref) => [
    TileAction(
      onPressed: (_) => _handleRemoveSubsystem(ref),
      backgroundColor: colorActionDelete,
      foregroundColor: Colors.white,
      icon: Icons.delete,
      label: context.l10n.delete,
    ),
  ];

  Widget _buildRecoveryRow(BuildContext context, WidgetRef ref, String title) {
    final content = ListTile(title: Text(title));
    if (!interactionOptions.allowMutations) {
      return content;
    }

    final startActions = _buildReplaceActions(context, ref);
    final endActions = _buildRemoveActions(context, ref);

    return Slidable(
      startActionPane: buildTileActionPane(startActions),
      endActionPane: buildTileActionPane(endActions, overflowFirst: true),
      child: SlidableEdgeZone(
        child: TileSecondaryActionRegion(actions: [...startActions, ...endActions], child: content),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemId = slotInfo.slot.itemId;
    final originTypeId = fitContext.resolveOriginTypeId(itemId);
    final displayTypeId = fitContext.resolveDisplayTypeId(itemId);
    if (originTypeId == null || displayTypeId == null) {
      return _buildRecoveryRow(
        context,
        ref,
        context.l10n.fitUnknownSubsystemWithIdAtSlot(itemId: itemId.asId, slot: slotInfo.index),
      );
    }

    final subsystemDef = ref.watch(
      repoCollectionProvider.select((c) => c?.getSubsystem(originTypeId)),
    );
    if (subsystemDef == null) {
      return _buildRecoveryRow(
        context,
        ref,
        context.l10n.fitUnknownSubsystemWithIdAtSlot(itemId: originTypeId, slot: slotInfo.index),
      );
    }

    final subsystemType = subsystemDef.subsystemType;
    final type = ref.watch(repoCollectionProvider.select((c) => c?.getType(displayTypeId)));

    final metaGroupIcon = type != null
        ? ref.watch(repoCollectionProvider.select((c) => c?.getMetaGroup(type.metaGroupId)?.icon))
        : null;

    final content = ListTile(
      leading: StateIcon.rect(
        state: slotInfo.state.toEfa(),
        child: type != null
            ? EveIcon(icon: type.icon, overlayIcon: metaGroupIcon, size: 35)
            : Image(
                image: switch (subsystemType) {
                  Subsystem_SubsystemType.CORE => ImageAssets.slotSubsystemCore,
                  Subsystem_SubsystemType.DEFENSIVE => ImageAssets.slotSubsystemDefensive,
                  Subsystem_SubsystemType.OFFENSIVE => ImageAssets.slotSubsystemOffensive,
                  Subsystem_SubsystemType.PROPULSION => ImageAssets.slotSubsystemPropulsion,
                  _ => ImageAssets.slotSubsystem,
                },
              ),
      ),
      title: LocalizedTypeName(typeId: displayTypeId),
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

    if (!interactionOptions.allowMutations) {
      return content;
    }

    final startActions = _buildReplaceActions(context, ref);
    final endActions = _buildRemoveActions(context, ref);

    return Slidable(
      startActionPane: buildTileActionPane(startActions),
      endActionPane: buildTileActionPane(endActions, overflowFirst: true),
      child: SlidableEdgeZone(
        child: TileSecondaryActionRegion(actions: [...startActions, ...endActions], child: content),
      ),
    );
  }
}
