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

  Widget _buildRecoveryRow(BuildContext context, WidgetRef ref, String title) {
    final content = ListTile(title: Text(title));
    if (!interactionOptions.allowMutations) {
      return content;
    }

    return Slidable(
      endActionPane: ActionPane(
        extentRatio: 0.15,
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _handleRemoveSubsystem(ref),
            backgroundColor: colorActionDelete,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: context.l10n.delete,
            padding: .zero,
          ),
        ],
      ),
      child: content,
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

    final subsystemDef = ref.watch(bundleCollectionGetSubsystemProvider(originTypeId));
    if (subsystemDef == null) {
      return _buildRecoveryRow(
        context,
        ref,
        context.l10n.fitUnknownSubsystemWithIdAtSlot(itemId: originTypeId, slot: slotInfo.index),
      );
    }

    final subsystemType = subsystemDef.subsystemType;
    final type = ref.watch(bundleCollectionGetTypeProvider(displayTypeId));

    final metaGroupIcon = type != null
        ? ref.watch(bundleCollectionGetMetaGroupProvider(type.metaGroupId).select((t) => t?.icon))
        : null;

    final content = ListTile(
      leading: StateIcon.rect(
        state: slotInfo.state,
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

    return Slidable(
      endActionPane: ActionPane(
        extentRatio: 0.15,
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _handleRemoveSubsystem(ref),
            backgroundColor: colorActionDelete,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: context.l10n.delete,
            padding: .zero,
          ),
        ],
      ),
      child: content,
    );
  }
}
