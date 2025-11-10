part of "../page.dart";

class _EquipmentTab extends ConsumerWidget {
  const _EquipmentTab({required this.fitContext});

  final FitContext fitContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = fitContext.fit;
    final fitWrapper = fitContext.fitWrapper;

    return ListView(
      children: [
        ...fit.body.slots.tacticalMode.match(
          () => const <Widget>[],
          (mode) => [
            _EquipmentHeader(title: context.l10n.tacticalMode),
            _AnySlotRow(
              fitContext: fitContext,
              slotIdent: const SlotIdentifier.tacticalMode(),
              slotInfo: SlotInfo.item(
                state: FitItemState.active,
                type: const native.OutSlotType.tacticalMode(),
                index: 0,
                slot: FitModuleItem(
                  charge: const Option.none(),
                  state: FitItemState.active,
                  itemId: FitStorageItemId.item(id: mode),
                ),
              ),
            ),
          ],
        ),
        if (fit.body.slots.high.isNotEmpty)
          _EquipmentHeader(
            title: context.l10n.highSlot,
            actions: [
              _ActionClearAll(onTap: () => fitWrapper.clearSlot(const SlotIdentifier.high(index: 0))),
              _ActionClearCharge(onTap: () => fitWrapper.clearSlotCharges(const SlotIdentifier.high(index: 0))),
            ],
          ),
        ...fit.body.slots.high.mapWithIndex(
          (slot, index) => _AnySlotRow(
            fitContext: fitContext,
            slotIdent: SlotIdentifier.high(index: index),
            slotInfo: slot.match(
              () => SlotInfo.empty(index: index),
              (slot) => SlotInfo.item(
                state: slot.state,
                type: const native.OutSlotType.high(),
                index: index,
                slot: slot,
              ),
            ),
          ),
        ),
        if (fit.body.slots.medium.isNotEmpty)
          _EquipmentHeader(
            title: context.l10n.midSlot,
            actions: [
              _ActionClearAll(onTap: () => fitWrapper.clearSlot(const SlotIdentifier.medium(index: 0))),
              _ActionClearCharge(onTap: () => fitWrapper.clearSlotCharges(const SlotIdentifier.medium(index: 0))),
            ],
          ),
        ...fit.body.slots.medium.mapWithIndex(
          (slot, index) => _AnySlotRow(
            fitContext: fitContext,
            slotIdent: SlotIdentifier.medium(index: index),
            slotInfo: slot.match(
              () => SlotInfo.empty(index: index),
              (slot) => SlotInfo.item(
                state: slot.state,
                type: const native.OutSlotType.high(),
                index: index,
                slot: slot,
              ),
            ),
          ),
        ),
        if (fit.body.slots.low.isNotEmpty)
          _EquipmentHeader(
            title: context.l10n.lowSlot,
            actions: [
              _ActionClearAll(onTap: () => fitWrapper.clearSlot(const SlotIdentifier.low(index: 0))),
              _ActionClearCharge(onTap: () => fitWrapper.clearSlotCharges(const SlotIdentifier.low(index: 0))),
            ],
          ),
        ...fit.body.slots.low.mapWithIndex(
          (slot, index) => _AnySlotRow(
            fitContext: fitContext,
            slotIdent: SlotIdentifier.low(index: index),
            slotInfo: slot.match(
              () => SlotInfo.empty(index: index),
              (slot) => SlotInfo.item(
                state: slot.state,
                type: const native.OutSlotType.high(),
                index: index,
                slot: slot,
              ),
            ),
          ),
        ),
        if (fit.body.slots.rig.isNotEmpty)
          _EquipmentHeader(
            title: context.l10n.rigSlot,
            actions: [_ActionClearAll(onTap: () => fitWrapper.clearSlot(const SlotIdentifier.rig(index: 0)))],
          ),
        ...fit.body.slots.rig.mapWithIndex(
          (slot, index) => _AnySlotRow(
            fitContext: fitContext,
            slotIdent: SlotIdentifier.rig(index: index),
            slotInfo: slot.match(
              () => SlotInfo.empty(index: index),
              (slot) => SlotInfo.item(
                state: slot.state,
                type: const native.OutSlotType.high(),
                index: index,
                slot: slot,
              ),
            ),
          ),
        ),
        if (fit.body.slots.subsystem.isNotEmpty)
          _EquipmentHeader(
            title: context.l10n.subsystemSlot,
            actions: [_ActionClearAll(onTap: () => fitWrapper.clearSlot(const SlotIdentifier.subsystem(index: 0)))],
          ),
        ...fit.body.slots.subsystem.mapWithIndex(
          (slot, index) => _AnySlotRow(
            fitContext: fitContext,
            slotIdent: SlotIdentifier.subsystem(index: index),
            slotInfo: slot.match(
              () => SlotInfo.empty(index: index),
              (slot) => SlotInfo.item(
                state: slot.state,
                type: const native.OutSlotType.high(),
                index: index,
                slot: slot,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
