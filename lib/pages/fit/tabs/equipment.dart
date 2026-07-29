part of "../page.dart";

class _EquipmentTab extends ConsumerStatefulWidget {
  const _EquipmentTab({
    required this.fitContext,
    this.interactionOptions = const FitInteractionOptions(),
  });

  final FitContext fitContext;
  final FitInteractionOptions interactionOptions;

  @override
  ConsumerState<_EquipmentTab> createState() => _EquipmentTabState();
}

class _EquipmentTabState extends ConsumerState<_EquipmentTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final fitContext = widget.fitContext;
    final interactionOptions = widget.interactionOptions;
    final fit = fitContext.fit;
    final subsystemSlotCount = fitContext.ship.subsystemSlots.clamp(
      0,
      fit.body.slots.subsystem.length,
    );
    final fitWrapper = fitContext.fitWrapper;

    return ListView(
      children: [
        ...fit.body.slots.tacticalMode.match(
          () => const <Widget>[],
          (mode) => [
            _EquipmentHeader(
              title: context.l10n.tacticalMode,
              issues: _collectFitIssuesForSection(
                context,
                ref,
                fitContext,
                _FitIssueSection.tacticalMode,
              ),
            ),
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
              interactionOptions: interactionOptions,
            ),
          ],
        ),
        if (fit.body.slots.high.isNotEmpty)
          _EquipmentHeader(
            title: context.l10n.highSlot,
            issues: _collectFitIssuesForSection(context, ref, fitContext, _FitIssueSection.high),
            actions: interactionOptions.allowMutations
                ? [
                    _ActionClearAll(
                      onTap: () => fitWrapper.clearSlot(const SlotIdentifier.high(index: 0)),
                    ),
                    _ActionClearCharge(
                      onTap: () => fitWrapper.clearSlotCharges(const SlotIdentifier.high(index: 0)),
                    ),
                  ]
                : const [],
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
            interactionOptions: interactionOptions,
          ),
        ),
        if (fit.body.slots.medium.isNotEmpty)
          _EquipmentHeader(
            title: context.l10n.midSlot,
            issues: _collectFitIssuesForSection(context, ref, fitContext, _FitIssueSection.medium),
            actions: interactionOptions.allowMutations
                ? [
                    _ActionClearAll(
                      onTap: () => fitWrapper.clearSlot(const SlotIdentifier.medium(index: 0)),
                    ),
                    _ActionClearCharge(
                      onTap: () =>
                          fitWrapper.clearSlotCharges(const SlotIdentifier.medium(index: 0)),
                    ),
                  ]
                : const [],
          ),
        ...fit.body.slots.medium.mapWithIndex(
          (slot, index) => _AnySlotRow(
            fitContext: fitContext,
            slotIdent: SlotIdentifier.medium(index: index),
            slotInfo: slot.match(
              () => SlotInfo.empty(index: index),
              (slot) => SlotInfo.item(
                state: slot.state,
                type: const native.OutSlotType.medium(),
                index: index,
                slot: slot,
              ),
            ),
            interactionOptions: interactionOptions,
          ),
        ),
        if (fit.body.slots.low.isNotEmpty)
          _EquipmentHeader(
            title: context.l10n.lowSlot,
            issues: _collectFitIssuesForSection(context, ref, fitContext, _FitIssueSection.low),
            actions: interactionOptions.allowMutations
                ? [
                    _ActionClearAll(
                      onTap: () => fitWrapper.clearSlot(const SlotIdentifier.low(index: 0)),
                    ),
                    _ActionClearCharge(
                      onTap: () => fitWrapper.clearSlotCharges(const SlotIdentifier.low(index: 0)),
                    ),
                  ]
                : const [],
          ),
        ...fit.body.slots.low.mapWithIndex(
          (slot, index) => _AnySlotRow(
            fitContext: fitContext,
            slotIdent: SlotIdentifier.low(index: index),
            slotInfo: slot.match(
              () => SlotInfo.empty(index: index),
              (slot) => SlotInfo.item(
                state: slot.state,
                type: const native.OutSlotType.low(),
                index: index,
                slot: slot,
              ),
            ),
            interactionOptions: interactionOptions,
          ),
        ),
        if (fit.body.slots.rig.isNotEmpty)
          _EquipmentHeader(
            title: context.l10n.rigSlot,
            issues: _collectFitIssuesForSection(context, ref, fitContext, _FitIssueSection.rig),
            actions: interactionOptions.allowMutations
                ? [
                    _ActionClearAll(
                      onTap: () => fitWrapper.clearSlot(const SlotIdentifier.rig(index: 0)),
                    ),
                  ]
                : const [],
          ),
        ...fit.body.slots.rig.mapWithIndex(
          (slot, index) => _AnySlotRow(
            fitContext: fitContext,
            slotIdent: SlotIdentifier.rig(index: index),
            slotInfo: slot.match(
              () => SlotInfo.empty(index: index),
              (slot) => SlotInfo.item(
                state: slot.state,
                type: const native.OutSlotType.rig(),
                index: index,
                slot: slot,
              ),
            ),
            interactionOptions: interactionOptions,
          ),
        ),
        if (subsystemSlotCount > 0)
          _EquipmentHeader(
            title: context.l10n.subsystemSlot,
            issues: _collectFitIssuesForSection(
              context,
              ref,
              fitContext,
              _FitIssueSection.subsystem,
            ),
            actions: interactionOptions.allowMutations
                ? [_ActionClearAll(onTap: () => fitWrapper.clearSubsystemAdjusted(fitContext.ship))]
                : const [],
          ),
        ...SubsystemType.allTypes
            .take(subsystemSlotCount)
            .map(
              (type) => _AnySlotRow(
                fitContext: fitContext,
                slotIdent: SlotIdentifier.subsystem(type: type),
                slotInfo: fit.body.slots.subsystem[type.index].match(
                  () => SlotInfo.empty(index: type.index),
                  (slot) => SlotInfo.item(
                    state: FitItemState.online,
                    type: const native.OutSlotType.subSystem(),
                    index: type.index,
                    slot: slot,
                  ),
                ),
                interactionOptions: interactionOptions,
              ),
            ),
      ],
    );
  }
}
