part of "../../../page.dart";

class _SubsystemSlotRow extends ConsumerWidget {
  const _SubsystemSlotRow({
    required this.fitContext,
    required this.slotIdent,
    required this.slotInfo,
  });

  final SlotIdentifierSubsystem slotIdent;
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

    final subsystemDef = ref.watch(bundleCollectionGetSubsystemProvider(itemId.asId));
    if (subsystemDef == null) {
      return ListTile(title: Text("Unknown Subsystem ${itemId.asId} at slot ${slotInfo.index}"));
    }

    final subsystemType = subsystemDef.subsystemType;
    final type = ref.watch(bundleCollectionGetTypeProvider(itemId.asId));

    final metaGroupIcon = type != null
        ? ref.watch(bundleCollectionGetMetaGroupProvider(type.metaGroupId).select((t) => t?.icon))
        : null;

    return Slidable(
      endActionPane: ActionPane(
        extentRatio: 0.15,
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) async {
              await fitContext.fitWrapper.removeSlotAdjusted(slotIdent, ref);
            },
            backgroundColor: const Color(0xFFFE4A49),
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: context.l10n.delete,
            padding: .zero,
          ),
        ],
      ),
      child: ListTile(
        leading: StateIcon.rect(
          state: slotInfo.state,
          onTap: () => fitContext.fitWrapper.toggleSlot(slotIdent, ref),
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
        title: LocalizedTypeName(typeId: itemId.asId),
      ),
    );
  }
}
