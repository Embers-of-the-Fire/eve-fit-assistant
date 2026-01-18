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

  IList<Option<FitModuleItem>> _emptySlotList(int len) =>
      IList(List.generate(len, (_) => const Option<FitModuleItem>.none()));

  // Public unified interfaces
  Future<void> equipSlot(SlotIdentifier slotIdent, int typeId, WidgetRef ref) async {
    final slotsInfo = ref.read(bundleCollectionGetSlotsProvider);
    if (slotsInfo == null) return;

    switch (slotIdent) {
      case SlotIdentifierHigh(:final index):
        final proto = slotsInfo.highSlots[typeId];
        if (proto != null) await _equipHigh(index, proto);
      case SlotIdentifierMedium(:final index):
        final proto = slotsInfo.mediumSlots[typeId];
        if (proto != null) await _equipMedium(index, proto);
      case SlotIdentifierLow(:final index):
        final proto = slotsInfo.lowSlots[typeId];
        if (proto != null) await _equipLow(index, proto);
      case SlotIdentifierRig(:final index):
        final proto = slotsInfo.rigSlots[typeId];
        if (proto != null) await _equipRig(index, proto);
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
            return _applySubsystemResize(
              afterEquip,
              ship,
              (id) => ref.read(bundleCollectionGetSubsystemProvider(id)),
            );
          });
        }
      case SlotIdentifierService(:final index):
        final proto = slotsInfo.serviceSlots[typeId];
        if (proto != null) await _equipService(index, proto);
      case SlotIdentifierDrone(:final groupId):
        await _equipDrone(groupId, typeId);
      default:
        break;
    }
  }

  Future<void> toggleSlot(SlotIdentifier slotIdent, WidgetRef ref) async {
    await wrapped.update((fit) {
      final slotsInfo = ref.read(bundleCollectionGetSlotsProvider);
      if (slotsInfo == null) return fit;

      final slotOpt = _getSlot(fit, slotIdent);
      if (slotOpt.isNone()) return fit;

      final slot = slotOpt.toNullable()!;
      final typeId = slot.itemId.asId;

      switch (slotIdent) {
        case SlotIdentifierHigh(:final index):
          final proto = slotsInfo.highSlots[typeId];
          if (proto == null) return fit;
          return _toggleHighSlot(fit, index, slot, proto);
        case SlotIdentifierMedium(:final index):
          final proto = slotsInfo.mediumSlots[typeId];
          if (proto == null) return fit;
          return _toggleMediumSlot(fit, index, slot, proto);
        case SlotIdentifierLow(:final index):
          final proto = slotsInfo.lowSlots[typeId];
          if (proto == null) return fit;
          return _toggleLowSlot(fit, index, slot, proto);
        case SlotIdentifierRig(:final index):
          final proto = slotsInfo.rigSlots[typeId];
          if (proto == null) return fit;
          return _toggleRigSlot(fit, index, slot, proto);
        case SlotIdentifierSubsystem(:final type):
          final proto = slotsInfo.subsystemSlots[typeId];
          if (proto == null) return fit;
          return _toggleSubsystemSlot(fit, type, slot, proto);
        case SlotIdentifierService(:final index):
          final proto = slotsInfo.serviceSlots[typeId];
          if (proto == null) return fit;
          return _toggleServiceSlot(fit, index, slot, proto);
        case SlotIdentifierDrone(:final groupId):
          return _toggleDroneSlot(fit, slot, groupId);
        default:
          return fit;
      }
    });
  }

  Future<void> clearSlot(SlotIdentifier slotIdent) async {
    switch (slotIdent) {
      case SlotIdentifierHigh _:
        await _clearHigh();
      case SlotIdentifierMedium _:
        await _clearMedium();
      case SlotIdentifierLow _:
        await _clearLow();
      case SlotIdentifierRig _:
        await _clearRig();
      case SlotIdentifierSubsystem _:
        await _clearSubsystem();
      case SlotIdentifierService _:
        await _clearService();
      case SlotIdentifierDrone _:
        await _clearDrones();
      default:
        break;
    }
  }

  Future<void> clearSlotCharges(SlotIdentifier slotIdent) async {
    switch (slotIdent) {
      case SlotIdentifierHigh _:
        await _clearHighCharges();
      case SlotIdentifierMedium _:
        await _clearMediumCharges();
      case SlotIdentifierLow _:
        await _clearLowCharges();
      default:
        break;
    }
  }

  Future<void> removeSlot(SlotIdentifier slotIdent) async {
    switch (slotIdent) {
      case SlotIdentifierHigh(:final index):
        await _removeHigh(index);
      case SlotIdentifierMedium(:final index):
        await _removeMedium(index);
      case SlotIdentifierLow(:final index):
        await _removeLow(index);
      case SlotIdentifierRig(:final index):
        await _removeRig(index);
      case SlotIdentifierSubsystem(:final type):
        await _removeSubsystem(type);
      case SlotIdentifierService(:final index):
        await _removeService(index);
      case SlotIdentifierDrone(:final groupId):
        await _removeDrone(groupId);
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
          return _applySubsystemResize(
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
        await _setHighCharge(index, chargeTypeId);
      case SlotIdentifierMedium(:final index):
        await _setMediumCharge(index, chargeTypeId);
      case SlotIdentifierLow(:final index):
        await _setLowCharge(index, chargeTypeId);
      default:
        break;
    }
  }

  Future<void> removeSlotCharge(SlotIdentifier slotIdent) async {
    switch (slotIdent) {
      case SlotIdentifierHigh(:final index):
        await _removeHighCharge(index);
      case SlotIdentifierMedium(:final index):
        await _removeMediumCharge(index);
      case SlotIdentifierLow(:final index):
        await _removeLowCharge(index);
      default:
        break;
    }
  }

  Future<void> copySlot(SlotIdentifier fromIdent, SlotIdentifier toIdent) async {
    await wrapped.update((fit) {
      final fromSlot = _getSlot(fit, fromIdent);
      if (fromSlot.isNone()) return fit;

      return _updateSlot(fit, toIdent, (_) => fromSlot);
    });
  }

  Future<void> copySlotToNext(SlotIdentifier slotIdent) async {
    await wrapped.update((fit) {
      final fromSlot = _getSlot(fit, slotIdent);
      if (fromSlot.isNone()) return fit;

      final slots = _getSlotList(fit, slotIdent);
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

      final targetIdent = _createSlotIdentifier(slotIdent, targetIndex);

      return _updateSlot(fit, targetIdent, (_) => fromSlot);
    });
  }

  IList<Option<FitModuleItem>> _getSlotList(FitStorage fit, SlotIdentifier slotIdent) =>
      switch (slotIdent) {
        SlotIdentifierHigh _ => fit.body.slots.high,
        SlotIdentifierMedium _ => fit.body.slots.medium,
        SlotIdentifierLow _ => fit.body.slots.low,
        SlotIdentifierRig _ => fit.body.slots.rig,
        SlotIdentifierSubsystem _ => fit.body.slots.subsystem,
        SlotIdentifierService _ => fit.body.slots.service,
        _ => IList<Option<FitModuleItem>>(),
      };

  SlotIdentifier _createSlotIdentifier(SlotIdentifier original, int newIndex) => switch (original) {
    SlotIdentifierHigh _ => SlotIdentifier.high(index: newIndex),
    SlotIdentifierMedium _ => SlotIdentifier.medium(index: newIndex),
    SlotIdentifierLow _ => SlotIdentifier.low(index: newIndex),
    SlotIdentifierRig _ => SlotIdentifier.rig(index: newIndex),
    SlotIdentifierSubsystem _ => SlotIdentifier.subsystem(type: SubsystemType.fromInt(newIndex)),
    SlotIdentifierService _ => SlotIdentifier.service(index: newIndex),
    _ => original,
  };

  Option<FitModuleItem> _getSlot(FitStorage fit, SlotIdentifier slotIdent) => switch (slotIdent) {
    SlotIdentifierHigh(:final index) => fit.body.slots.high[index],
    SlotIdentifierMedium(:final index) => fit.body.slots.medium[index],
    SlotIdentifierLow(:final index) => fit.body.slots.low[index],
    SlotIdentifierRig(:final index) => fit.body.slots.rig[index],
    SlotIdentifierSubsystem(:final type) => fit.body.slots.subsystem[type.index],
    SlotIdentifierService(:final index) => fit.body.slots.service[index],
    SlotIdentifierDrone(:final groupId) => _getDroneAsModule(fit, groupId),
    _ => const Option.none(),
  };

  FitStorage _updateSlot(
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

  Future<void> _equipHigh(int index, Slots_HighSlot slotInfo) => wrapped.update((fit) {
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

  Future<void> _equipMedium(int index, Slots_GeneralSlot slotInfo) => wrapped.update((fit) {
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

  Future<void> _equipLow(int index, Slots_GeneralSlot slotInfo) => wrapped.update((fit) {
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

  Future<void> _equipRig(int index, Slots_GeneralSlot slotInfo) => wrapped.update((fit) {
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

  Future<void> _equipService(int index, Slots_GeneralSlot slotInfo) => wrapped.update((fit) {
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

  FitStorage _toggleHighSlot(
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

  FitStorage _toggleMediumSlot(
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

  FitStorage _toggleLowSlot(
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

  FitStorage _toggleRigSlot(
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

  FitStorage _toggleSubsystemSlot(
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

  FitStorage _toggleServiceSlot(
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

  Future<void> _clearHigh() => wrapped.update((fit) {
    final len = fit.body.slots.high.length;
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(high: _emptySlotList(len))),
    );
  });
  Future<void> _clearHighCharges() => wrapped.update((fit) {
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

  Future<void> _clearMedium() => wrapped.update((fit) {
    final len = fit.body.slots.medium.length;
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(medium: _emptySlotList(len))),
    );
  });
  Future<void> _clearMediumCharges() => wrapped.update((fit) {
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

  Future<void> _clearLow() => wrapped.update((fit) {
    final len = fit.body.slots.low.length;
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(low: _emptySlotList(len))),
    );
  });
  Future<void> _clearLowCharges() => wrapped.update((fit) {
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

  Future<void> _clearRig() => wrapped.update((fit) {
    final len = fit.body.slots.rig.length;
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(rig: _emptySlotList(len))),
    );
  });

  Future<void> _clearSubsystem() => wrapped.update((fit) {
    final len = fit.body.slots.subsystem.length;
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(subsystem: _emptySlotList(len))),
    );
  });

  Future<void> _clearService() => wrapped.update((fit) {
    final len = fit.body.slots.service.length;
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(service: _emptySlotList(len))),
    );
  });

  Future<void> _removeHigh(int index) => wrapped.update((fit) {
    final updatedHigh = fit.body.slots.high.replaceBy(index, (_) => const Option.none());
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(high: updatedHigh)),
    );
  });

  Future<void> _removeMedium(int index) => wrapped.update((fit) {
    final updatedMedium = fit.body.slots.medium.replaceBy(index, (_) => const Option.none());
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(medium: updatedMedium)),
    );
  });

  Future<void> _removeLow(int index) => wrapped.update((fit) {
    final updatedLow = fit.body.slots.low.replaceBy(index, (_) => const Option.none());
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(low: updatedLow)),
    );
  });

  Future<void> _removeRig(int index) => wrapped.update((fit) {
    final updatedRig = fit.body.slots.rig.replaceBy(index, (_) => const Option.none());
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(rig: updatedRig)),
    );
  });

  Future<void> _removeSubsystem(SubsystemType type) => wrapped.update((fit) {
    final updatedSubsystem = fit.body.slots.subsystem.replaceBy(
      type.index,
      (_) => const Option.none(),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(subsystem: updatedSubsystem)),
    );
  });

  Future<void> _removeService(int index) => wrapped.update((fit) {
    final updatedService = fit.body.slots.service.replaceBy(index, (_) => const Option.none());
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(service: updatedService)),
    );
  });

  Future<void> _setHighCharge(int index, int chargeTypeId) => wrapped.update((fit) {
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

  Future<void> _setMediumCharge(int index, int chargeTypeId) => wrapped.update((fit) {
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

  Future<void> _setLowCharge(int index, int chargeTypeId) => wrapped.update((fit) {
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

  Future<void> _removeHighCharge(int index) => wrapped.update((fit) {
    final updatedHigh = fit.body.slots.high.replaceBy(
      index,
      (slotOpt) => slotOpt.map((slot) => slot.copyWith(charge: const Option.none())),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(high: updatedHigh)),
    );
  });

  Future<void> _removeMediumCharge(int index) => wrapped.update((fit) {
    final updatedMedium = fit.body.slots.medium.replaceBy(
      index,
      (slotOpt) => slotOpt.map((slot) => slot.copyWith(charge: const Option.none())),
    );
    return fit.copyWith(
      body: fit.body.copyWith(slots: fit.body.slots.copyWith(medium: updatedMedium)),
    );
  });

  Future<void> _removeLowCharge(int index) => wrapped.update((fit) {
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
  Option<FitModuleItem> _getDroneAsModule(FitStorage fit, int groupId) {
    final drone = fit.body.drones.firstWhereOrNull((d) => d.groupId == groupId);
    if (drone == null) return const Option.none();
    return Option.of(
      FitModuleItem(itemId: drone.itemId, charge: const Option.none(), state: drone.state),
    );
  }

  Future<void> _equipDrone(int groupId, int typeId) => wrapped.update((fit) {
    final hasGroup = fit.body.drones.any((d) => d.groupId == groupId);
    final newDrone = FitDroneItem(
      itemId: FitStorageItemId.item(id: typeId),
      groupId: groupId,
      state: FitItemState.active,
    );

    if (!hasGroup) {
      return fit.copyWith(body: fit.body.copyWith(drones: fit.body.drones.add(newDrone)));
    }

    final updated = fit.body.drones
        .map((d) => d.groupId == groupId ? newDrone.copyWith(state: FitItemState.active) : d)
        .toIList();
    return fit.copyWith(body: fit.body.copyWith(drones: updated));
  });

  FitStorage _toggleDroneSlot(FitStorage fit, FitModuleItem slot, int groupId) {
    final first = fit.body.drones.firstWhereOrNull((d) => d.groupId == groupId);
    if (first == null) return fit;

    final newState = first.state.toggleDrone();
    final updated = fit.body.drones
        .map((d) => d.groupId == groupId ? d.copyWith(state: newState) : d)
        .toIList();

    return fit.copyWith(body: fit.body.copyWith(drones: updated));
  }

  Future<void> _clearDrones() =>
      wrapped.update((fit) => fit.copyWith(body: fit.body.copyWith(drones: IList<FitDroneItem>())));

  Future<void> _removeDrone(int groupId) => wrapped.update((fit) {
    final updatedDrones = fit.body.drones.where((d) => d.groupId != groupId).toIList();
    return fit.copyWith(body: fit.body.copyWith(drones: updatedDrones));
  });

  FitStorage _applySubsystemResize(
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
