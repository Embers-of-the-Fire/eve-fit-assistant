part of "page.dart";

class FitWrapper {
  const FitWrapper({required this.wrapped});

  final Fit wrapped;

  Future<void> update(FitStorage Function(FitStorage) updater) => wrapped.update(updater);

  IList<Option<FitModuleItem>> _emptySlotList(int len) =>
      IList(List.generate(len, (_) => const Option<FitModuleItem>.none()));


  Future<void> clearHigh() => wrapped.update((fit) {
    final len = fit.body.slots.high.length;
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(high: _emptySlotList(len))),
    );
  });
  Future<void> clearHighCharges() => wrapped.update((fit) {
    final updatedHigh = fit.body.slots.high.map((slotOpt) => slotOpt.map((slot) {
          if (slot.charge.isNone()) return slot;
          return slot.copyWith(charge: const Option.none());
        }));
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
            .map((slotOpt) => slotOpt.map((slot) {
                  if (slot.charge.isNone()) return slot;
                  return slot.copyWith(charge: const Option.none());
                }))
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
            .map((slotOpt) => slotOpt.map((slot) {
                  if (slot.charge.isNone()) return slot;
                  return slot.copyWith(charge: const Option.none());
                }))
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
