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

  ActionPane _buildReplaceActionPane(BuildContext context, WidgetRef ref) => ActionPane(
    extentRatio: 0.15,
    motion: const StretchMotion(),
    children: [
      SlidableAction(
        onPressed: (_) => _handleReplaceSubsystem(context, ref),
        backgroundColor: Colors.grey.shade200,
        foregroundColor: Colors.black,
        icon: Icons.change_circle_outlined,
        label: context.l10n.edit,
        padding: .zero,
      ),
    ],
  );

  Widget _buildRecoveryRow(BuildContext context, WidgetRef ref, String title) {
    final content = ListTile(title: Text(title));
    if (!interactionOptions.allowMutations) {
      return content;
    }

    return Slidable(
      startActionPane: _buildReplaceActionPane(context, ref),
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
      child: SlidableEdgeZone(child: content),
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
      startActionPane: _buildReplaceActionPane(context, ref),
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
      child: SlidableEdgeZone(child: content),
    );
  }
}
