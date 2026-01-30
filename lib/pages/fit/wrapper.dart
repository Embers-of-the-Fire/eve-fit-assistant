part of "page.dart";

class FitContext {
  const FitContext({
    required this.fit,
    required this.fitWrapper,
    required this.emulated,
    required this.ship,
  });

  final FitStorage fit;
  final FitWrapper fitWrapper;
  final native.Ship? emulated;
  final Ship ship;
}

class FitWrapper {
  const FitWrapper({required this.wrapped, required this.fitId});

  final Fit wrapped;
  final String fitId;

  Future<void> update(FitStorage Function(FitStorage) updater) => wrapped.update(updater);

  IList<Option<FitModuleItem>> emptySlotList(int len) =>
      IList(List.generate(len, (_) => const Option<FitModuleItem>.none()));

  // Public unified interfaces
  Future<void> equipSlot(SlotIdentifier slotIdent, int typeId, WidgetRef ref) async {
    final slotsInfo = ref.read(bundleCollectionGetSlotsProvider);
    if (slotsInfo == null) return;

    switch (slotIdent) {
      case SlotIdentifierHigh(:final index):
        final proto = slotsInfo.highSlots[typeId];
        if (proto != null) await equipHigh(index, proto);
      case SlotIdentifierMedium(:final index):
        final proto = slotsInfo.mediumSlots[typeId];
        if (proto != null) await equipMedium(index, proto);
      case SlotIdentifierLow(:final index):
        final proto = slotsInfo.lowSlots[typeId];
        if (proto != null) await equipLow(index, proto);
      case SlotIdentifierRig(:final index):
        final proto = slotsInfo.rigSlots[typeId];
        if (proto != null) await equipRig(index, proto);
      case SlotIdentifierSubsystem(:final type):
        final proto = slotsInfo.subsystemSlots[typeId];
        if (proto != null) {
          final ship = ref.read(
            bundleCollectionGetShipProvider(ref.read(fitProvider(fitId)).fit.body.shipTypeId),
          );
          if (ship == null) return;
          await wrapped.update((fit) {
            final updatedSubsystem = fit.body.slots.subsystem.replaceBy(
              type.index,
              (_) => Option.of(
                FitModuleItem(
                  itemId: FitStorageItemId.item(id: proto.typeId),
                  charge: const Option.none(),
                  state: proto.maxState.dartImpl.limitToActive,
                ),
              ),
            );
            final afterEquip = fit.copyWith(
              body: fit.body.copyWith(slots: fit.body.slots.copyWith(subsystem: updatedSubsystem)),
            );
            return applySubsystemResize(
              afterEquip,
              ship,
              (id) => ref.read(bundleCollectionGetSubsystemProvider(id)),
            );
          });
        }
      case SlotIdentifierService(:final index):
        final proto = slotsInfo.serviceSlots[typeId];
        if (proto != null) await equipService(index, proto);
      case SlotIdentifierDrone(:final index):
        await equipDrone(index, typeId);
      default:
        break;
    }
  }

  Future<void> toggleSlot(SlotIdentifier slotIdent, WidgetRef ref) async {
    await wrapped.update((fit) {
      final slotsInfo = ref.read(bundleCollectionGetSlotsProvider);
      if (slotsInfo == null) return fit;

      final slotOpt = getSlot(fit, slotIdent);
      if (slotOpt.isNone()) return fit;

      final slot = slotOpt.toNullable()!;
      final typeId = slot.itemId.asId;

      switch (slotIdent) {
        case SlotIdentifierHigh(:final index):
          final proto = slotsInfo.highSlots[typeId];
          if (proto == null) return fit;
          return toggleHighSlot(fit, index, slot, proto);
        case SlotIdentifierMedium(:final index):
          final proto = slotsInfo.mediumSlots[typeId];
          if (proto == null) return fit;
          return toggleMediumSlot(fit, index, slot, proto);
        case SlotIdentifierLow(:final index):
          final proto = slotsInfo.lowSlots[typeId];
          if (proto == null) return fit;
          return toggleLowSlot(fit, index, slot, proto);
        case SlotIdentifierRig(:final index):
          final proto = slotsInfo.rigSlots[typeId];
          if (proto == null) return fit;
          return toggleRigSlot(fit, index, slot, proto);
        case SlotIdentifierSubsystem(:final type):
          final proto = slotsInfo.subsystemSlots[typeId];
          if (proto == null) return fit;
          return toggleSubsystemSlot(fit, type, slot, proto);
        case SlotIdentifierService(:final index):
          final proto = slotsInfo.serviceSlots[typeId];
          if (proto == null) return fit;
          return toggleServiceSlot(fit, index, slot, proto);
        case SlotIdentifierDrone(:final index):
          return toggleDroneSlot(fit, slot, index);
        default:
          return fit;
      }
    });
  }

  Future<void> clearSlot(SlotIdentifier slotIdent) async {
    switch (slotIdent) {
      case SlotIdentifierHigh _:
        await clearHigh();
      case SlotIdentifierMedium _:
        await clearMedium();
      case SlotIdentifierLow _:
        await clearLow();
      case SlotIdentifierRig _:
        await clearRig();
      case SlotIdentifierSubsystem _:
        await clearSubsystem();
      case SlotIdentifierService _:
        await clearService();
      case SlotIdentifierDrone _:
        await clearDrones();
      default:
        break;
    }
  }

  Future<void> clearSlotCharges(SlotIdentifier slotIdent) async {
    switch (slotIdent) {
      case SlotIdentifierHigh _:
        await clearHighCharges();
      case SlotIdentifierMedium _:
        await clearMediumCharges();
      case SlotIdentifierLow _:
        await clearLowCharges();
      default:
        break;
    }
  }

  Future<void> removeSlot(SlotIdentifier slotIdent) async {
    switch (slotIdent) {
      case SlotIdentifierHigh(:final index):
        await removeHigh(index);
      case SlotIdentifierMedium(:final index):
        await removeMedium(index);
      case SlotIdentifierLow(:final index):
        await removeLow(index);
      case SlotIdentifierRig(:final index):
        await removeRig(index);
      case SlotIdentifierSubsystem(:final type):
        await removeSubsystem(type);
      case SlotIdentifierService(:final index):
        await removeService(index);
      case SlotIdentifierDrone(:final index):
        await removeDrone(index);
      default:
        break;
    }
  }

  Future<void> removeSlotAdjusted(SlotIdentifier slotIdent, WidgetRef ref) async {
    switch (slotIdent) {
      case SlotIdentifierSubsystem(:final type):
        final fitState = ref.read(fitProvider(fitId));
        if (!fitState.isInitialized) return;
        final ship = ref.read(bundleCollectionGetShipProvider(fitState.fit.body.shipTypeId));
        if (ship == null) return;
        await wrapped.update((fit) {
          final updatedSubsystem = fit.body.slots.subsystem.replaceBy(
            type.index,
            (_) => const Option.none(),
          );
          final afterRemove = fit.copyWith(
            body: fit.body.copyWith(slots: fit.body.slots.copyWith(subsystem: updatedSubsystem)),
          );
          return applySubsystemResize(
            afterRemove,
            ship,
            (id) => ref.read(bundleCollectionGetSubsystemProvider(id)),
          );
        });
      default:
        await removeSlot(slotIdent);
    }
  }

  Future<void> setSlotCharge(SlotIdentifier slotIdent, int chargeTypeId) async {
    switch (slotIdent) {
      case SlotIdentifierHigh(:final index):
        await setHighCharge(index, chargeTypeId);
      case SlotIdentifierMedium(:final index):
        await setMediumCharge(index, chargeTypeId);
      case SlotIdentifierLow(:final index):
        await setLowCharge(index, chargeTypeId);
      default:
        break;
    }
  }

  Future<void> removeSlotCharge(SlotIdentifier slotIdent) async {
    switch (slotIdent) {
      case SlotIdentifierHigh(:final index):
        await removeHighCharge(index);
      case SlotIdentifierMedium(:final index):
        await removeMediumCharge(index);
      case SlotIdentifierLow(:final index):
        await removeLowCharge(index);
      default:
        break;
    }
  }

  Future<void> copySlot(SlotIdentifier fromIdent, SlotIdentifier toIdent) async {
    await wrapped.update((fit) {
      final fromSlot = getSlot(fit, fromIdent);
      if (fromSlot.isNone()) return fit;

      return updateSlot(fit, toIdent, (_) => fromSlot);
    });
  }

  Future<void> copySlotToNext(SlotIdentifier slotIdent) async {
    await wrapped.update((fit) {
      final fromSlot = getSlot(fit, slotIdent);
      if (fromSlot.isNone()) return fit;

      final slots = getSlotList(fit, slotIdent);
      final currentIndex = slotIdent.asIndexed;

      int? targetIndex;

      for (int i = currentIndex + 1; i < slots.length; i++) {
        if (slots[i].isNone()) {
          targetIndex = i;
          break;
        }
      }

      if (targetIndex == null) {
        for (int i = 0; i < currentIndex; i++) {
          if (slots[i].isNone()) {
            targetIndex = i;
            break;
          }
        }
      }

      if (targetIndex == null) return fit;

      final targetIdent = createSlotIdentifier(slotIdent, targetIndex);

      return updateSlot(fit, targetIdent, (_) => fromSlot);
    });
  }

  IList<Option<FitModuleItem>> getSlotList(FitStorage fit, SlotIdentifier slotIdent) =>
      switch (slotIdent) {
        SlotIdentifierHigh _ => fit.body.slots.high,
        SlotIdentifierMedium _ => fit.body.slots.medium,
        SlotIdentifierLow _ => fit.body.slots.low,
        SlotIdentifierRig _ => fit.body.slots.rig,
        SlotIdentifierSubsystem _ => fit.body.slots.subsystem,
        SlotIdentifierService _ => fit.body.slots.service,
        _ => IList<Option<FitModuleItem>>(),
      };

  SlotIdentifier createSlotIdentifier(SlotIdentifier original, int newIndex) => switch (original) {
    SlotIdentifierHigh _ => SlotIdentifier.high(index: newIndex),
    SlotIdentifierMedium _ => SlotIdentifier.medium(index: newIndex),
    SlotIdentifierLow _ => SlotIdentifier.low(index: newIndex),
    SlotIdentifierRig _ => SlotIdentifier.rig(index: newIndex),
    SlotIdentifierSubsystem _ => SlotIdentifier.subsystem(type: SubsystemType.fromInt(newIndex)),
    SlotIdentifierService _ => SlotIdentifier.service(index: newIndex),
    _ => original,
  };

  Option<FitModuleItem> getSlot(FitStorage fit, SlotIdentifier slotIdent) => switch (slotIdent) {
    SlotIdentifierHigh(:final index) => fit.body.slots.high[index],
    SlotIdentifierMedium(:final index) => fit.body.slots.medium[index],
    SlotIdentifierLow(:final index) => fit.body.slots.low[index],
    SlotIdentifierRig(:final index) => fit.body.slots.rig[index],
    SlotIdentifierSubsystem(:final type) => fit.body.slots.subsystem[type.index],
    SlotIdentifierService(:final index) => fit.body.slots.service[index],
    SlotIdentifierDrone(:final index) => getDroneAsModule(fit, index),
    _ => const Option.none(),
  };

  FitStorage updateSlot(
    FitStorage fit,
    SlotIdentifier slotIdent,
    Option<FitModuleItem> Function(Option<FitModuleItem>) updater,
  ) => switch (slotIdent) {
    SlotIdentifierHigh(:final index) => fit.copyWith(
      body: fit.body.copyWith(
        slots: fit.body.slots.copyWith(high: fit.body.slots.high.replaceBy(index, updater)),
      ),
    ),
    SlotIdentifierMedium(:final index) => fit.copyWith(
      body: fit.body.copyWith(
        slots: fit.body.slots.copyWith(medium: fit.body.slots.medium.replaceBy(index, updater)),
      ),
    ),
    SlotIdentifierLow(:final index) => fit.copyWith(
      body: fit.body.copyWith(
        slots: fit.body.slots.copyWith(low: fit.body.slots.low.replaceBy(index, updater)),
      ),
    ),
    SlotIdentifierRig(:final index) => fit.copyWith(
      body: fit.body.copyWith(
        slots: fit.body.slots.copyWith(rig: fit.body.slots.rig.replaceBy(index, updater)),
      ),
    ),
    SlotIdentifierSubsystem(:final type) => fit.copyWith(
      body: fit.body.copyWith(
        slots: fit.body.slots.copyWith(
          subsystem: fit.body.slots.subsystem.replaceBy(type.index, updater),
        ),
      ),
    ),
    SlotIdentifierService(:final index) => fit.copyWith(
      body: fit.body.copyWith(
        slots: fit.body.slots.copyWith(service: fit.body.slots.service.replaceBy(index, updater)),
      ),
    ),
    _ => fit,
  };

  Future<void> equipHigh(int index, Slots_HighSlot slotInfo) => wrapped.update((fit) {
    final updatedHigh = fit.body.slots.high.replaceBy(
      index,
      (_) => Option.of(
        FitModuleItem(
          itemId: FitStorageItemId.item(id: slotInfo.typeId),
          charge: const Option.none(),
          state: slotInfo.maxState.dartImpl.limitToActive,
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
          state: slotInfo.maxState.dartImpl.limitToActive,
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
          state: slotInfo.maxState.dartImpl.limitToActive,
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
          state: slotInfo.maxState.dartImpl.limitToActive,
        ),
      ),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(rig: updatedRig)),
    );
  });

  Future<void> equipService(int index, Slots_GeneralSlot slotInfo) => wrapped.update((fit) {
    final updatedService = fit.body.slots.service.replaceBy(
      index,
      (_) => Option.of(
        FitModuleItem(
          itemId: FitStorageItemId.item(id: slotInfo.typeId),
          charge: const Option.none(),
          state: slotInfo.maxState.dartImpl.limitToActive,
        ),
      ),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(service: updatedService)),
    );
  });

  FitStorage toggleHighSlot(
    FitStorage fit,
    int index,
    FitModuleItem slot,
    Slots_HighSlot slotInfo,
  ) {
    final newState = slot.state.toggle(slotInfo.maxState.dartImpl);
    final updatedHigh = fit.body.slots.high.replaceBy(
      index,
      (_) => Option.of(slot.copyWith(state: newState)),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(high: updatedHigh)),
    );
  }

  FitStorage toggleMediumSlot(
    FitStorage fit,
    int index,
    FitModuleItem slot,
    Slots_GeneralSlot slotInfo,
  ) {
    final newState = slot.state.toggle(slotInfo.maxState.dartImpl);
    final updatedMedium = fit.body.slots.medium.replaceBy(
      index,
      (_) => Option.of(slot.copyWith(state: newState)),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(medium: updatedMedium)),
    );
  }

  FitStorage toggleLowSlot(
    FitStorage fit,
    int index,
    FitModuleItem slot,
    Slots_GeneralSlot slotInfo,
  ) {
    final newState = slot.state.toggle(slotInfo.maxState.dartImpl);
    final updatedLow = fit.body.slots.low.replaceBy(
      index,
      (_) => Option.of(slot.copyWith(state: newState)),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(low: updatedLow)),
    );
  }

  FitStorage toggleRigSlot(
    FitStorage fit,
    int index,
    FitModuleItem slot,
    Slots_GeneralSlot slotInfo,
  ) {
    final newState = slot.state.toggle(slotInfo.maxState.dartImpl);
    final updatedRig = fit.body.slots.rig.replaceBy(
      index,
      (_) => Option.of(slot.copyWith(state: newState)),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(rig: updatedRig)),
    );
  }

  FitStorage toggleSubsystemSlot(
    FitStorage fit,
    SubsystemType type,
    FitModuleItem slot,
    Slots_GeneralSlot slotInfo,
  ) {
    final newState = slot.state.toggle(slotInfo.maxState.dartImpl);
    final updatedSubsystem = fit.body.slots.subsystem.replaceBy(
      type.index,
      (_) => Option.of(slot.copyWith(state: newState)),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(subsystem: updatedSubsystem)),
    );
  }

  FitStorage toggleServiceSlot(
    FitStorage fit,
    int index,
    FitModuleItem slot,
    Slots_GeneralSlot slotInfo,
  ) {
    final newState = slot.state.toggle(slotInfo.maxState.dartImpl);
    final updatedService = fit.body.slots.service.replaceBy(
      index,
      (_) => Option.of(slot.copyWith(state: newState)),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(service: updatedService)),
    );
  }

  Future<void> clearHigh() => wrapped.update((fit) {
    final len = fit.body.slots.high.length;
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(high: emptySlotList(len))),
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
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(medium: emptySlotList(len))),
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
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(low: emptySlotList(len))),
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
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(rig: emptySlotList(len))),
    );
  });

  Future<void> clearSubsystem() => wrapped.update((fit) {
    final len = fit.body.slots.subsystem.length;
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(subsystem: emptySlotList(len))),
    );
  });

  Future<void> clearService() => wrapped.update((fit) {
    final len = fit.body.slots.service.length;
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(service: emptySlotList(len))),
    );
  });

  Future<void> removeHigh(int index) => wrapped.update((fit) {
    final updatedHigh = fit.body.slots.high.replaceBy(index, (_) => const Option.none());
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(high: updatedHigh)),
    );
  });

  Future<void> removeMedium(int index) => wrapped.update((fit) {
    final updatedMedium = fit.body.slots.medium.replaceBy(index, (_) => const Option.none());
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(medium: updatedMedium)),
    );
  });

  Future<void> removeLow(int index) => wrapped.update((fit) {
    final updatedLow = fit.body.slots.low.replaceBy(index, (_) => const Option.none());
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(low: updatedLow)),
    );
  });

  Future<void> removeRig(int index) => wrapped.update((fit) {
    final updatedRig = fit.body.slots.rig.replaceBy(index, (_) => const Option.none());
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(rig: updatedRig)),
    );
  });

  Future<void> removeSubsystem(SubsystemType type) => wrapped.update((fit) {
    final updatedSubsystem = fit.body.slots.subsystem.replaceBy(
      type.index,
      (_) => const Option.none(),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(subsystem: updatedSubsystem)),
    );
  });

  Future<void> removeService(int index) => wrapped.update((fit) {
    final updatedService = fit.body.slots.service.replaceBy(index, (_) => const Option.none());
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(service: updatedService)),
    );
  });

  Future<void> setHighCharge(int index, int chargeTypeId) => wrapped.update((fit) {
    final updatedHigh = fit.body.slots.high.replaceBy(
      index,
      (slotOpt) => slotOpt.map(
        (slot) => slot.copyWith(charge: Option.of(FitChargeItem(typeId: chargeTypeId))),
      ),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(high: updatedHigh)),
    );
  });

  Future<void> setMediumCharge(int index, int chargeTypeId) => wrapped.update((fit) {
    final updatedMedium = fit.body.slots.medium.replaceBy(
      index,
      (slotOpt) => slotOpt.map(
        (slot) => slot.copyWith(charge: Option.of(FitChargeItem(typeId: chargeTypeId))),
      ),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(medium: updatedMedium)),
    );
  });

  Future<void> setLowCharge(int index, int chargeTypeId) => wrapped.update((fit) {
    final updatedLow = fit.body.slots.low.replaceBy(
      index,
      (slotOpt) => slotOpt.map(
        (slot) => slot.copyWith(charge: Option.of(FitChargeItem(typeId: chargeTypeId))),
      ),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(low: updatedLow)),
    );
  });

  Future<void> removeHighCharge(int index) => wrapped.update((fit) {
    final updatedHigh = fit.body.slots.high.replaceBy(
      index,
      (slotOpt) => slotOpt.map((slot) => slot.copyWith(charge: const Option.none())),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(high: updatedHigh)),
    );
  });

  Future<void> removeMediumCharge(int index) => wrapped.update((fit) {
    final updatedMedium = fit.body.slots.medium.replaceBy(
      index,
      (slotOpt) => slotOpt.map((slot) => slot.copyWith(charge: const Option.none())),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(medium: updatedMedium)),
    );
  });

  Future<void> removeLowCharge(int index) => wrapped.update((fit) {
    final updatedLow = fit.body.slots.low.replaceBy(
      index,
      (slotOpt) => slotOpt.map((slot) => slot.copyWith(charge: const Option.none())),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(low: updatedLow)),
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

  // Drone-related methods
  Option<FitModuleItem> getDroneAsModule(FitStorage fit, int index) {
    if (index < 0 || index >= fit.body.drones.length) return const Option.none();
    final drone = fit.body.drones[index];
    return Option.of(
      FitModuleItem(itemId: drone.itemId, charge: const Option.none(), state: drone.state),
    );
  }

  Future<void> equipDrone(int index, int typeId) => wrapped.update((fit) {
    if (index < 0) return fit;
    final newDrone = FitDroneItem(
      itemId: FitStorageItemId.item(id: typeId),
      state: FitItemState.active,
      quantity: 1,
    );

    final drones = fit.body.drones.toList();
    if (index >= drones.length) {
      drones.add(newDrone);
    } else {
      drones[index] = newDrone;
    }

    return fit.copyWith(body: fit.body.copyWith(drones: drones.toIList()));
  });

  FitStorage toggleDroneSlot(FitStorage fit, FitModuleItem _slot, int index) {
    if (index < 0 || index >= fit.body.drones.length) return fit;

    final drone = fit.body.drones[index];
    final newState = drone.state.toggleDrone();
    final drones = fit.body.drones.toList();
    drones[index] = drone.copyWith(state: newState);

    return fit.copyWith(body: fit.body.copyWith(drones: drones.toIList()));
  }

  Future<void> clearDrones() =>
      wrapped.update((fit) => fit.copyWith(body: fit.body.copyWith(drones: IList<FitDroneItem>())));

  Future<void> removeDrone(int index) => wrapped.update((fit) {
    if (index < 0 || index >= fit.body.drones.length) return fit;
    final drones = fit.body.drones.toList()..removeAt(index);
    return fit.copyWith(body: fit.body.copyWith(drones: drones.toIList()));
  });

  Future<void> changeDroneAmount(int index, int newAmount) => wrapped.update((fit) {
    if (index < 0 || index >= fit.body.drones.length) return fit;
    final drones = fit.body.drones.toList();
    if (newAmount <= 0) {
      drones.removeAt(index);
    } else {
      drones[index] = drones[index].copyWith(quantity: newAmount);
    }
    return fit.copyWith(body: fit.body.copyWith(drones: drones.toIList()));
  });

  Future<void> changeDroneAmountBy(int index, int diff) => wrapped.update((fit) {
    if (index < 0 || index >= fit.body.drones.length) return fit;
    final drones = fit.body.drones.toList();
    final currentAmount = drones[index].quantity;
    final newAmount = currentAmount + diff;
    if (newAmount <= 0) {
      drones.removeAt(index);
    } else {
      drones[index] = drones[index].copyWith(quantity: newAmount);
    }
    return fit.copyWith(body: fit.body.copyWith(drones: drones.toIList()));
  });

  FitStorage applySubsystemResize(
    FitStorage fit,
    Ship ship,
    Subsystem? Function(int typeId) resolve,
  ) {
    final installed = fit.body.slots.subsystem
        .map((opt) => opt.toNullable()?.itemId.asId)
        .whereType<int>()
        .toList();

    final defs = installed.map((id) => resolve(id)).whereType<Subsystem>().toList();

    int newHigh;
    int newMedium;
    int newLow;

    if (defs.isEmpty) {
      newHigh = ship.highSlots;
      newMedium = ship.mediumSlots;
      newLow = ship.lowSlots;
    } else {
      newHigh = defs.fold<int>(0, (sum, s) => sum + s.highSlots);
      newMedium = defs.fold<int>(0, (sum, s) => sum + s.mediumSlots);
      newLow = defs.fold<int>(0, (sum, s) => sum + s.lowSlots);
    }

    IList<Option<FitModuleItem>> resize(IList<Option<FitModuleItem>> current, int target) {
      if (target == current.length) return current;
      if (target < current.length) {
        return IList(current.take(target));
      }
      final extra = List<Option<FitModuleItem>>.generate(
        target - current.length,
        (_) => const Option<FitModuleItem>.none(),
      );
      return IList([...current, ...extra]);
    }

    final updatedSlots = fit.body.slots.copyWith(
      high: resize(fit.body.slots.high, newHigh),
      medium: resize(fit.body.slots.medium, newMedium),
      low: resize(fit.body.slots.low, newLow),
    );

    return fit.copyWith(body: fit.body.copyWith(slots: updatedSlots));
  }
}
