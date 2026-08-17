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

  List<TileAction> _buildStartActions(BuildContext context, WidgetRef ref) => <TileAction>[
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

    final content = ListTile(
      leading: StateIcon.rect(
        state: slotInfo.state.toEfa(),
        onTap: interactionOptions.allowStateToggle
            ? () => fitContext.fitWrapper.toggleSlot(slotIdent, ref)
            : null,
        child: EveIcon(icon: typeDef.icon, overlayIcon: metaGroupIcon, size: 35),
      ),
      title: LocalizedTypeName(typeId: displayTypeId),
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
        child: TileSecondaryActionRegion(actions: [...startActions, ...endActions], child: content),
      ),
    );
  }
}
