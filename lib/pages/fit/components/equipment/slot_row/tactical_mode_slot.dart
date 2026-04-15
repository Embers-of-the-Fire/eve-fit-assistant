part of "../../../page.dart";

class _TacticalModeSlotRow extends StatelessWidget {
  const _TacticalModeSlotRow({
    required this.fitContext,
    required this.slotIdent,
    required this.slotInfo,
    required this.interactionOptions,
  });

  final SlotIdentifierTacticalMode slotIdent;
  final _ItemSlotInfo slotInfo;
  final FitContext fitContext;
  final FitInteractionOptions interactionOptions;

  @override
  Widget build(BuildContext context) {
    final tacticalModeDef = fitContext.ship.tacticalModes
        .where((t) => t.typeId == slotInfo.slot.itemId.asId)
        .firstOrNull;
    final variant = tacticalModeDef?.variant;
    if (variant == null) {
      return ListTile(
        title: Text(context.l10n.fitUnknownTacticalMode(typeId: slotInfo.slot.itemId.asId)),
      );
    }
    return ListTile(
      onTap: interactionOptions.allowMutations && interactionOptions.allowStateToggle
          ? () => fitContext.fitWrapper.toggleTacticalMode(fitContext.ship)
          : null,
      onLongPress: interactionOptions.allowInspect
          ? () => showItemDetailPage(
              context,
              typeId: slotInfo.slot.itemId.asId,
              fitReference: ItemDetailFitReference.module(
                fitId: fitContext.fitId,
                slotType: slotInfo.type,
                index: slotInfo.index,
              ),
            )
          : null,
      leading: StateIcon.circle(
        state: slotInfo.state,
        child: Image(
          image: switch (variant) {
            TacticalMode_TacticalModeVariant.TARGET => ImageAssets.tacticalModeTarget,
            TacticalMode_TacticalModeVariant.SPEED => ImageAssets.tacticalModeSpeed,
            _ => ImageAssets.tacticalModeDefense,
          },
        ),
      ),
      title: LocalizedTypeName(typeId: slotInfo.slot.itemId.asId),
    );
  }
}
