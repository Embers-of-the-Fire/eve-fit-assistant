part of "../../page.dart";

class _EmptySlotRow extends StatelessWidget {
  const _EmptySlotRow({required this.slotIdent, required this.slotInfo});

  final SlotIdentifier slotIdent;
  final _EmptySlotInfo slotInfo;

  @override
  Widget build(BuildContext context) =>
      ListTile(title: Text("Empty Slot $slotIdent at ${slotInfo.index}"));
}
