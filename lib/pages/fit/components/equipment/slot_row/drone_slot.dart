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

  Future<void> _handleSetAmount(BuildContext context, WidgetRef ref, int amount) async {
    await fitContext.fitWrapper.changeDroneAmount(slotIdent.index, amount);
  }

  Future<void> _handleAddAmount(BuildContext context, WidgetRef ref, int diff) async {
    await fitContext.fitWrapper.changeDroneAmountBy(slotIdent.index, diff);
  }

  Future<void> _handleRemoveDrone(BuildContext context, WidgetRef ref) async {
    await fitContext.fitWrapper.removeDrone(slotIdent.index);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemId = slotInfo.slot.itemId;
    if (itemId is! FitStorageItemIdItem) {
      return ListTile(
        title: Text("${slotInfo.state} at ${slotInfo.index}[${slotInfo.slot}]: ${slotInfo.type}"),
      );
    }

    final typeDef = ref.watch(bundleCollectionGetTypeProvider(itemId.asId));
    if (typeDef == null) {
      return ListTile(title: Text("Unknown Item ${itemId.asId} at slot ${slotInfo.index}"));
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
        title: LocalizedTypeName(typeId: itemId.asId),
        trailing: Text("x $quantity"),
      ),
    );
  }
}
