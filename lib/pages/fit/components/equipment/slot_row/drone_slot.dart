part of "../../../page.dart";

class _DroneSlotRow extends ConsumerWidget {
  const _DroneSlotRow({required this.fitContext, required this.slotIdent, required this.slotInfo});

  final SlotIdentifierDrone slotIdent;
  final _ItemSlotInfo slotInfo;
  final FitContext fitContext;

  List<SlidableAction> _buildStartActions(BuildContext context, WidgetRef ref) => <SlidableAction>[
    if (fitContext.fit.body.drones.getOrNull(slotIdent.index)?.quantity != 1)
      SlidableAction(
        onPressed: (_) => _handleSetAmount(context, ref, 1),
        backgroundColor: Colors.green.shade200,
        foregroundColor: Colors.black,
        label: "x1",
        padding: .zero,
      ),
    if (fitContext.fit.body.drones.getOrNull(slotIdent.index)?.quantity != 5)
      SlidableAction(
        onPressed: (_) => _handleSetAmount(context, ref, 5),
        backgroundColor: Colors.green.shade400,
        foregroundColor: Colors.white,
        label: "x5",
        padding: .zero,
      ),
  ];

  List<SlidableAction> _buildEndActions(BuildContext context, WidgetRef ref) => <SlidableAction>[
    if ((fitContext.fit.body.drones.getOrNull(slotIdent.index)?.quantity ?? 0) > 1)
      SlidableAction(
        onPressed: (_) => _handleAddAmount(context, ref, -1),
        autoClose: false,
        backgroundColor: Colors.red.shade400,
        foregroundColor: Colors.white,
        label: "-1",
        padding: .zero,
      ),
    SlidableAction(
      onPressed: (_) => _handleAddAmount(context, ref, 1),
      autoClose: false,
      backgroundColor: Colors.green.shade400,
      foregroundColor: Colors.black,
      label: "+1",
      padding: .zero,
    ),
    SlidableAction(
      onPressed: (_) => _handleRemoveDrone(context, ref),
      backgroundColor: colorActionDelete,
      foregroundColor: Colors.white,
      icon: Icons.delete,
      label: context.l10n.delete,
      padding: .zero,
    ),
  ];

  List<SlidableAction> _buildRecoveryActions(BuildContext context, WidgetRef ref) =>
      <SlidableAction>[
        SlidableAction(
          onPressed: (_) => _handleRemoveDrone(context, ref),
          backgroundColor: colorActionDelete,
          foregroundColor: Colors.white,
          icon: Icons.delete,
          label: context.l10n.delete,
          padding: .zero,
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

    return Slidable(
      endActionPane: ActionPane(
        extentRatio: 0.15 * recoveryActions.length,
        motion: const StretchMotion(),
        children: recoveryActions,
      ),
      child: ListTile(title: Text(title), trailing: Text("x $quantity")),
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
        "Unknown Item ${itemId.asId} at slot ${slotInfo.index}",
      );
    }

    final typeDef = ref.watch(bundleCollectionGetTypeProvider(displayTypeId));
    if (typeDef == null) {
      return _buildRecoveryRow(
        context,
        ref,
        "Unknown Item $displayTypeId at slot ${slotInfo.index}",
      );
    }

    final metaGroupIcon = ref.watch(
      bundleCollectionGetMetaGroupProvider(typeDef.metaGroupId).select((t) => t?.icon),
    );

    final startActions = _buildStartActions(context, ref);
    final endActions = _buildEndActions(context, ref);

    final quantity = fitContext.fit.body.drones.getOrNull(slotIdent.index)?.quantity ?? 0;

    return Slidable(
      startActionPane: ActionPane(
        extentRatio: 0.15 * startActions.length,
        motion: const StretchMotion(),
        children: startActions,
      ),
      endActionPane: ActionPane(
        extentRatio: 0.15 * endActions.length,
        motion: const StretchMotion(),
        children: endActions,
      ),
      child: ListTile(
        leading: StateIcon.rect(
          state: slotInfo.state,
          onTap: () => fitContext.fitWrapper.toggleSlot(slotIdent, ref),
          child: EveIcon(icon: typeDef.icon, overlayIcon: metaGroupIcon, size: 35),
        ),
        title: LocalizedTypeName(typeId: displayTypeId),
        trailing: Text("x $quantity"),
        onTap: () => showItemDetailPage(
          context,
          typeId: displayTypeId,
          fitReference: ItemDetailFitReference.module(
            fitId: fitContext.fitId,
            index: slotInfo.index,
          ),
        ),
      ),
    );
  }
}
