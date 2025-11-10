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
      leading: BorderedRectAvatar(
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
            await fitContext.fitWrapper.equipSlot(slotIdent, found, ref);
          }),
      trailing: Text("${slotIdent.asIndexed + 1}"),
    );
  }
}
