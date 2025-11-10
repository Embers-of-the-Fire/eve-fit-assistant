part of "page.dart";

class FitContext {
  const FitContext({required this.fit, required this.fitWrapper, required this.ship});

  final FitStorage fit;
  final FitWrapper fitWrapper;
  final Ship ship;
}

class FitWrapper {
  const FitWrapper({required this.wrapped});

  final Fit wrapped;

  Future<void> update(FitStorage Function(FitStorage) updater) => wrapped.update(updater);

  IList<Option<FitModuleItem>> _emptySlotList(int len) =>
      IList(List.generate(len, (_) => const Option<FitModuleItem>.none()));

  Future<void> equipHigh(int index, Slots_HighSlot slotInfo) => wrapped.update((fit) {
    final updatedHigh = fit.body.slots.high.replaceBy(
      index,
      (_) => Option.of(
        FitModuleItem(
          itemId: FitStorageItemId.item(id: slotInfo.typeId),
          charge: const Option.none(),
          state: slotInfo.maxState.dartImpl,
        ),
      ),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(high: updatedHigh)),
    );
  });

  Future<void> equipMedium(int index, Slots_GeneralSlot slotInfo) => wrapped.update((fit) {
    final updatedMedium = fit.body.slots.medium.replaceBy(
      index,
      (_) => Option.of(
        FitModuleItem(
          itemId: FitStorageItemId.item(id: slotInfo.typeId),
          charge: const Option.none(),
          state: slotInfo.maxState.dartImpl,
        ),
      ),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(medium: updatedMedium)),
    );
  });

  Future<void> equipLow(int index, Slots_GeneralSlot slotInfo) => wrapped.update((fit) {
    final updatedLow = fit.body.slots.low.replaceBy(
      index,
      (_) => Option.of(
        FitModuleItem(
          itemId: FitStorageItemId.item(id: slotInfo.typeId),
          charge: const Option.none(),
          state: slotInfo.maxState.dartImpl,
        ),
      ),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(low: updatedLow)),
    );
  });

  Future<void> equipRig(int index, Slots_GeneralSlot slotInfo) => wrapped.update((fit) {
    final updatedRig = fit.body.slots.rig.replaceBy(
      index,
      (_) => Option.of(
        FitModuleItem(
          itemId: FitStorageItemId.item(id: slotInfo.typeId),
          charge: const Option.none(),
          state: slotInfo.maxState.dartImpl,
        ),
      ),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(rig: updatedRig)),
    );
  });

  Future<void> equipSubsystem(int index, Slots_GeneralSlot slotInfo) => wrapped.update((fit) {
    final updatedSubsystem = fit.body.slots.subsystem.replaceBy(
      index,
      (_) => Option.of(
        FitModuleItem(
          itemId: FitStorageItemId.item(id: slotInfo.typeId),
          charge: const Option.none(),
          state: slotInfo.maxState.dartImpl,
        ),
      ),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(subsystem: updatedSubsystem)),
    );
  });

  Future<void> equipService(int index, Slots_GeneralSlot slotInfo) => wrapped.update((fit) {
    final updatedService = fit.body.slots.service.replaceBy(
      index,
      (_) => Option.of(
        FitModuleItem(
          itemId: FitStorageItemId.item(id: slotInfo.typeId),
          charge: const Option.none(),
          state: slotInfo.maxState.dartImpl,
        ),
      ),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(service: updatedService)),
    );
  });

  Future<void> clearHigh() => wrapped.update((fit) {
    final len = fit.body.slots.high.length;
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(high: _emptySlotList(len))),
    );
  });
  Future<void> clearHighCharges() => wrapped.update((fit) {
    final updatedHigh = fit.body.slots.high.map(
      (slotOpt) => slotOpt.map((slot) {
        if (slot.charge.isNone()) return slot;
        return slot.copyWith(charge: const Option.none());
      }),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(high: IList(updatedHigh))),
    );
  });

  Future<void> clearMedium() => wrapped.update((fit) {
    final len = fit.body.slots.medium.length;
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(medium: _emptySlotList(len))),
    );
  });
  Future<void> clearMediumCharges() => wrapped.update((fit) {
    final updatedMedium = fit.body.slots.medium
        .map(
          (slotOpt) => slotOpt.map((slot) {
            if (slot.charge.isNone()) return slot;
            return slot.copyWith(charge: const Option.none());
          }),
        )
        .toList();
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(medium: IList(updatedMedium))),
    );
  });

  Future<void> clearLow() => wrapped.update((fit) {
    final len = fit.body.slots.low.length;
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(low: _emptySlotList(len))),
    );
  });
  Future<void> clearLowCharges() => wrapped.update((fit) {
    final updatedLow = fit.body.slots.low
        .map(
          (slotOpt) => slotOpt.map((slot) {
            if (slot.charge.isNone()) return slot;
            return slot.copyWith(charge: const Option.none());
          }),
        )
        .toList();
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(low: IList(updatedLow))),
    );
  });

  Future<void> clearRig() => wrapped.update((fit) {
    final len = fit.body.slots.rig.length;
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(rig: _emptySlotList(len))),
    );
  });

  Future<void> clearSubsystem() => wrapped.update((fit) {
    final len = fit.body.slots.subsystem.length;
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(subsystem: _emptySlotList(len))),
    );
  });

  Future<void> clearService() => wrapped.update((fit) {
    final len = fit.body.slots.service.length;
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(service: _emptySlotList(len))),
    );
  });

  Future<void> toggleTacticalMode(Ship ship) async {
    final hasTacticalMode = ship.tacticalModes.isNotEmpty;
    if (!hasTacticalMode) return;
    return wrapped.update(
      (fit) => fit.body.slots.tacticalMode.match(
        () => fit,
        (current) => fit.copyWith(
          body: fit.body.copyWith(
            slots: fit.body.slots.copyWith(
              tacticalMode: Option.of(
                ship.tacticalModes.cycle().skipTo((t) => t.typeId == current).first.typeId,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
