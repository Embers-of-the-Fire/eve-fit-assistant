part of "../../page.dart";

class _AnySlotRow extends StatelessWidget {
  const _AnySlotRow({required this.slotIdent, required this.slotInfo});

  final SlotIdentifier slotIdent;
  final SlotInfo slotInfo;

  @override
  Widget build(BuildContext context) => slotInfo.when(
    empty: (index) => _EmptySlotRow(
      slotIdent: slotIdent,
      slotInfo: _EmptySlotInfo(index: index),
    ),
    item: (state, type, index, slot) => _SlotRow(
      slotIdent: slotIdent,
      slotInfo: _ItemSlotInfo(state: state, type: type, index: index, slot: slot),
    ),
  );
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.slotIdent, required this.slotInfo});

  final SlotIdentifier slotIdent;
  final _ItemSlotInfo slotInfo;

  @override
  Widget build(BuildContext context) {
    final slotHasCharge = slotInfo.slot.charge.isSome();

    return ListTile(
      title: Text(
        "${slotInfo.state} at ${slotInfo.index}[${slotInfo.slot}]: ${slotInfo.type} ($slotHasCharge)",
      ),
    );
  }
}
