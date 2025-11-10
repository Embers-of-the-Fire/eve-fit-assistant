part of "../../page.dart";

class _EmptySlotRow extends ConsumerWidget {
  const _EmptySlotRow({required this.slotIdent, required this.slotInfo, required this.fitContext});

  final SlotIdentifier slotIdent;
  final _EmptySlotInfo slotInfo;
  final FitContext fitContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ImageProvider? display = switch (slotIdent) {
      SlotIdentifierHigh _ => ImageAssets.slotHigh,
      SlotIdentifierMedium _ => ImageAssets.slotMedium,
      SlotIdentifierLow _ => ImageAssets.slotLow,
      SlotIdentifierRig _ => ImageAssets.slotRig,
      _ => null,
    };

    return ListTile(
      leading: BorderedCircleAvatar(
        size: 35,
        backgroundColor: colorStatusPassive,
        borderColor: colorStatusPassive,
        image: display,
        icon: display.reverseMap(() => Icons.add_circle_outline),
      ),
      title: Text(context.l10n.fitSlotEmpty(slotName: slotIdent.localizedSlotName(context))),
      onTap: () =>
          showAddItemDialog(
            context: context,
            title: slotIdent.localizedAddItemDialogTitle(context),
            initialMarketGroupId: slotIdent.baseMarketGroupId,
            validator: slotIdent.validator(ref),
          ).then((found) async {
            if (found == null) return;
            final slotsInfo = ref.read(bundleCollectionGetSlotsProvider);
            if (slotsInfo == null) return;

            switch (slotIdent) {
              case SlotIdentifierHigh _:
                final proto = slotsInfo.highSlots[found];
                if (proto != null) await fitContext.fitWrapper.equipHigh(slotInfo.index, proto);
              case SlotIdentifierMedium _:
                final proto = slotsInfo.mediumSlots[found];
                if (proto != null) await fitContext.fitWrapper.equipMedium(slotInfo.index, proto);
              case SlotIdentifierLow _:
                final proto = slotsInfo.lowSlots[found];
                if (proto != null) await fitContext.fitWrapper.equipLow(slotInfo.index, proto);
              case SlotIdentifierRig _:
                final proto = slotsInfo.rigSlots[found];
                if (proto != null) await fitContext.fitWrapper.equipRig(slotInfo.index, proto);
              case SlotIdentifierSubsystem _:
                final proto = slotsInfo.subsystemSlots[found];
                if (proto != null) await fitContext.fitWrapper.equipSubsystem(slotInfo.index, proto);
              case SlotIdentifierService _:
                final proto = slotsInfo.serviceSlots[found];
                if (proto != null) await fitContext.fitWrapper.equipService(slotInfo.index, proto);
              default:
                // Other slot types (tacticalMode, drone, fighter, implant, booster) are
                // not handled here. Add handling if needed.
                break;
            }
          }),
      trailing: Text("${slotIdent.asIndexed + 1}"),
    );
  }
}
