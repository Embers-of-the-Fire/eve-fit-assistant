part of "../../page.dart";

class _EmptySlotRow extends StatelessWidget {
  const _EmptySlotRow({required this.slotIdent, required this.slotInfo});

  final SlotIdentifier slotIdent;
  final _EmptySlotInfo slotInfo;

  @override
  Widget build(BuildContext context) {
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
      title: Text("missing $slotIdent"),
      onTap: () {},
      trailing: Text("${slotIdent.asIndexed + 1}"),
    );
  }
}
