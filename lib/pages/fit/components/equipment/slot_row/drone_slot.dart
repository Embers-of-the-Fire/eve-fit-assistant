part of "../../../page.dart";

class _DroneSlotRow extends ConsumerWidget {
  const _DroneSlotRow({required this.fitContext, required this.slotIdent, required this.slotInfo});

  final SlotIdentifierDrone slotIdent;
  final _ItemSlotInfo slotInfo;
  final FitContext fitContext;

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

    return Slidable(
      child: ListTile(
        leading: StateIcon.rect(
          state: slotInfo.state,
          onTap: () => fitContext.fitWrapper.toggleSlot(slotIdent, ref),
          child: EveIcon(icon: typeDef.icon, overlayIcon: metaGroupIcon, size: 35),
        ),
        title: LocalizedTypeName(typeId: itemId.asId),
      ),
    );
  }
}
