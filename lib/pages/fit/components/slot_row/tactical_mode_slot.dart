part of "../../page.dart";

class _TacticalModeSlotRow extends StatelessWidget {
  const _TacticalModeSlotRow({
    required this.fitContext,
    required this.slotIdent,
    required this.slotInfo,
  });

  final SlotIdentifierTacticalMode slotIdent;
  final _ItemSlotInfo slotInfo;
  final FitContext fitContext;

  @override
  Widget build(BuildContext context) {
    final tacticalModeDef = fitContext.ship.tacticalModes
        .where((t) => t.typeId == slotInfo.slot.itemId.asId)
        .firstOrNull;
    final variant = tacticalModeDef?.variant;
    if (variant == null) {
      return ListTile(title: Text("Unknown Tactical Mode ${slotInfo.slot.itemId.asId}"));
    }
    return ListTile(
      onTap: () => fitContext.fitWrapper.toggleTacticalMode(fitContext.ship),
      leading: StateIcon(
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
