part of "../../page.dart";

class _AnySlotRow extends StatelessWidget {
  const _AnySlotRow({required this.fitContext, required this.slotIdent, required this.slotInfo});

  final FitContext fitContext;
  final SlotIdentifier slotIdent;
  final SlotInfo slotInfo;

  @override
  Widget build(BuildContext context) => slotInfo.when(
    empty: (index) => _EmptySlotRow(
      slotIdent: slotIdent,
      slotInfo: _EmptySlotInfo(index: index),
      fitContext: fitContext,
    ),
    item: (state, type, index, slot) => _SlotRow(
      fitContext: fitContext,
      slotIdent: slotIdent,
      slotInfo: _ItemSlotInfo(state: state, type: type, index: index, slot: slot),
    ),
  );
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.fitContext, required this.slotIdent, required this.slotInfo});

  final FitContext fitContext;
  final SlotIdentifier slotIdent;
  final _ItemSlotInfo slotInfo;

  @override
  Widget build(BuildContext context) {
    final slotHasCharge = slotInfo.slot.charge.isSome();

    switch (slotIdent) {
      case final SlotIdentifierTacticalMode mode:
        return _TacticalModeSlotRow(fitContext: fitContext, slotIdent: mode, slotInfo: slotInfo);

      default:
        return ListTile(
          title: Text(
            "${slotInfo.state} at ${slotInfo.index}[${slotInfo.slot}]: ${slotInfo.type} ($slotHasCharge)",
          ),
        );
    }
  }
}
