part of "page.dart";

class FitContext {
  const FitContext({
    required this.fitId,
    required this.fit,
    required this.fitWrapper,
    required this.emulated,
    required this.ship,
  });

  final String fitId;
  final FitStorage fit;
  final FitWrapper fitWrapper;
  final native.Ship? emulated;
  final Ship ship;

  FitDynamicItem? dynamicItemFor(FitStorageItemId itemId) => itemId.when(
    item: (_) => null,
    dynamic: (dynamicId) => fit.dynamicRegistry.dynamicItems[dynamicId],
  );

  int? resolveDisplayTypeId(FitStorageItemId itemId) => itemId.when(
    item: (id) => id,
    dynamic: (dynamicId) => fit.dynamicRegistry.dynamicItems[dynamicId]?.typeId,
  );

  int? resolveOriginTypeId(FitStorageItemId itemId) => itemId.when(
    item: (id) => id,
    dynamic: (dynamicId) => fit.dynamicRegistry.dynamicItems[dynamicId]?.originTypeId,
  );
}

enum _FighterCategory { light, support, heavy }

const int _fighterMissilesEffectId = 6431;
const int _fighterAttackMissileEffectId = 6465;
const int _fighterBombEffectId = 6485;

_FighterCategory? _fighterCategoryFromGroupId(int groupId) => switch (groupId) {
  1652 || 4777 => _FighterCategory.light,
  1537 || 4778 => _FighterCategory.support,
  1653 || 4779 => _FighterCategory.heavy,
  _ => null,
};

class FitWrapper {
  const FitWrapper({required this.wrapped, required this.fitId, required this.ref});

  final Fit wrapped;
  final String fitId;
  final WidgetRef ref;

  Future<void> update(FitStorage Function(FitStorage) updater) => wrapped.update(updater);

  Future<void> setCharacter(String characterId) =>
      wrapped.update((fit) => fit.copyWith(body: fit.body.copyWith(characterId: characterId)));

  int _allocateDynamicItemId(FitStorage fit) => allocateDynamicItemId(fit);

  FitDynamicItem? _dynamicItemForId(FitStorage fit, int dynamicId) =>
      fit.dynamicRegistry.dynamicItems[dynamicId];

  FitStorage _storeDynamicItem(FitStorage fit, FitDynamicItem dynamicItem) => fit.copyWith(
    dynamicRegistry: fit.dynamicRegistry.copyWith(
      dynamicItems: fit.dynamicRegistry.dynamicItems.add(dynamicItem.dynamicItemId, dynamicItem),
    ),
  );

  FitStorage? _updateDynamicItem(
    FitStorage fit,
    int dynamicId,
    FitDynamicItem Function(FitDynamicItem dynamicItem) updater,
  ) {
    final dynamicItem = _dynamicItemForId(fit, dynamicId);
    if (dynamicItem == null) {
      warning("Missing dynamic item $dynamicId while updating fit item");
      return null;
    }

    return _storeDynamicItem(fit, updater(dynamicItem));
  }

  (FitStorage, FitStorageItemId) _cloneStorageItemId(FitStorage fit, FitStorageItemId itemId) =>
      itemId.when(
        item: (id) => (fit, FitStorageItemId.item(id: id)),
        dynamic: (dynamicId) {
          final dynamicItem = fit.dynamicRegistry.dynamicItems[dynamicId];
          if (dynamicItem == null) {
            warning("Missing dynamic item $dynamicId while copying fit item");
            return (fit, FitStorageItemId.dynamic(dynamicId: dynamicId));
          }

          final clonedDynamicId = _allocateDynamicItemId(fit);
          final clonedDynamicItem = dynamicItem.copyWith(dynamicItemId: clonedDynamicId);
          final updatedFit = _storeDynamicItem(fit, clonedDynamicItem);
          return (updatedFit, FitStorageItemId.dynamic(dynamicId: clonedDynamicId));
        },
      );

  (FitStorage, FitModuleItem) _cloneModuleItem(FitStorage fit, FitModuleItem slot) {
    final (updatedFit, itemId) = _cloneStorageItemId(fit, slot.itemId);
    return (updatedFit, slot.copyWith(itemId: itemId));
  }

  int? _resolveOriginTypeId(FitStorage fit, FitStorageItemId itemId) => itemId.when(
    item: (id) => id,
    dynamic: (dynamicId) => fit.dynamicRegistry.dynamicItems[dynamicId]?.originTypeId,
  );

  int _fighterCategoryLimit(native.Ship? emulated, _FighterCategory category) {
    final hull = emulated?.hull;
    if (hull == null) return 0;

    return switch (category) {
      _FighterCategory.light => hull.getAttribute(EveConstAttrID.fighterLightSlots).round(),
      _FighterCategory.support => hull.getAttribute(EveConstAttrID.fighterSupportSlots).round(),
      _FighterCategory.heavy => hull.getAttribute(EveConstAttrID.fighterHeavySlots).round(),
    };
  }

  int _fighterCategoryCount(FitStorage fit, _FighterCategory category) =>
      fit.body.fighters.where((fighter) {
        final typeId = _resolveOriginTypeId(fit, fighter.itemId);
        if (typeId == null) return false;

        final type = ref.read(bundleCollectionGetTypeProvider(typeId));
        if (type == null) return false;

        return _fighterCategoryFromGroupId(type.groupId) == category;
      }).length;

  Future<int?> _resolveDefaultFighterQuantity(FitStorage fit, int typeId, int groupId) async {
    try {
      final tempFighters = fit.body.fighters.toList()
        ..add(
          FitFighterItem(
            itemId: FitStorageItemId.item(id: typeId),
            groupId: groupId,
            quantity: 1,
            fighterAbility: 0,
          ),
        );
      final tempFit = fit.copyWith(
        body: fit.body.copyWith(fighters: _normalizeFighters(tempFighters)),
      );
      final characterId = tempFit.body.characterId;
      final engine = ref.read(nativeFitEngineServiceProvider).engineOrNull;
      final availableSkillTypeIds = ref.read(bundleCollectionSkillTypeIdsProvider);
      final characterSkills = await ref
          .read(characterRegistryManagerProvider.notifier)
          .resolveCharacterSkills(characterId, availableSkillTypeIds);
      if (ref.read(fitProvider(fitId)).fit.body.characterId != characterId) {
        return null;
      }
      if (engine == null) {
        warning("Fit engine unavailable while resolving fighter squadron max size for $typeId");
        return null;
      }
      final output = await engine.emulate(
        fit: convertToNative(tempFit, characterSkills: characterSkills),
      );
      if (ref.read(fitProvider(fitId)).fit.body.characterId != characterId) {
        return null;
      }

      for (final item in output.modules) {
        final slotType = item.slot.slotType;
        if (slotType case native.OutSlotType_Fighter(:final groupId)) {
          if (groupId != tempFighters.length - 1) continue;

          final quantity = item.getAttribute(EveConstAttrID.fighterSquadronMaxSize).round();
          if (quantity > 0) return quantity;
        }
      }
    } on Object catch (error, stackTrace) {
      warning("Failed to resolve fighter squadron max size for $typeId: $error");
      debug(error.toString(), stackTrace: stackTrace);
    }

    return null;
  }

  IList<FitFighterItem> _normalizeFighters(Iterable<FitFighterItem> fighters) =>
      IList(fighters.mapWithIndex((fighter, index) => fighter.copyWith(groupId: index)));

  // Implants are serialized as a plain array, but the authoritative slot id for
  // each implant still comes from bundle metadata. We therefore keep array
  // storage while resolving the logical slot from the fitted type whenever the
  // UI needs slot-aware behavior.
  Future<void> setImplant(int index, int typeId) => wrapped.update((fit) {
    final implants = fit.body.implants.toList();
    final implant = FitImplantItem(
      itemId: FitStorageItemId.item(id: typeId),
      state: FitItemState.online,
    );

    if (index < 0) return fit;
    if (index < implants.length) {
      implants[index] = implant;
    } else if (index == implants.length) {
      implants.add(implant);
    } else {
      warning("Cannot set implant at sparse index $index with current fit storage layout");
      return fit;
    }

    return fit.copyWith(body: fit.body.copyWith(implants: implants.toIList()));
  });

  Future<void> removeImplant(int index) => wrapped.update((fit) {
    if (index < 0 || index >= fit.body.implants.length) return fit;
    final implants = fit.body.implants.toList()..removeAt(index);
    return fit.copyWith(body: fit.body.copyWith(implants: implants.toIList()));
  });

  Future<void> clearImplants() =>
      wrapped.update((fit) => fit.copyWith(body: fit.body.copyWith(implants: IList())));

  // Boosters already carry their own slot id in storage, so replacement is
  // keyed by that slot instead of by list position.
  Future<void> setBooster(int slotId, int typeId) => wrapped.update((fit) {
    final boosters = fit.body.boosters.toList();
    final newBooster = FitBoosterItem(
      itemId: FitStorageItemId.item(id: typeId),
      index: slotId,
      state: FitItemState.online,
    );
    final existingIndex = boosters.indexWhere((booster) => booster.index == slotId);

    if (existingIndex >= 0) {
      boosters[existingIndex] = newBooster;
    } else {
      boosters
        ..add(newBooster)
        ..sort((left, right) => left.index.compareTo(right.index));
    }

    return fit.copyWith(body: fit.body.copyWith(boosters: boosters.toIList()));
  });

  Future<void> removeBooster(int slotId) => wrapped.update((fit) {
    final boosters = fit.body.boosters.where((booster) => booster.index != slotId).toIList();
    return fit.copyWith(body: fit.body.copyWith(boosters: boosters));
  });

  Future<void> clearBoosters() =>
      wrapped.update((fit) => fit.copyWith(body: fit.body.copyWith(boosters: IList())));

  int? findImplantStorageIndex(FitStorage fit, int slotId, WidgetRef ref) {
    final slotsInfo = ref.read(bundleCollectionGetSlotsProvider);
    if (slotsInfo == null) return null;

    for (final (index, implant) in fit.body.implants.mapWithIndex(
      (implant, index) => (index, implant),
    )) {
      final typeId = switch (implant.itemId) {
        FitStorageItemIdItem(:final id) => id,
        _ => null,
      };
      if (typeId == null) continue;
      if (slotsInfo.implantSlots[typeId]?.slotIndex == slotId + 1) return index;
    }

    return null;
  }

  Future<void> equipImplantForSlot(int slotId, int typeId, WidgetRef ref) => wrapped.update((fit) {
    final implants = fit.body.implants.toList();
    final implant = FitImplantItem(
      itemId: FitStorageItemId.item(id: typeId),
      state: FitItemState.online,
    );
    final existingIndex = findImplantStorageIndex(fit, slotId, ref);

    if (existingIndex == null) {
      implants.add(implant);
    } else {
      implants[existingIndex] = implant;
    }

    return fit.copyWith(body: fit.body.copyWith(implants: implants.toIList()));
  });

  Future<void> removeImplantForSlot(int slotId, WidgetRef ref) => wrapped.update((fit) {
    final existingIndex = findImplantStorageIndex(fit, slotId, ref);
    if (existingIndex == null) return fit;
    final implants = fit.body.implants.toList()..removeAt(existingIndex);
    return fit.copyWith(body: fit.body.copyWith(implants: implants.toIList()));
  });

  Future<void> toggleImplantForSlot(int slotId, WidgetRef ref) => wrapped.update((fit) {
    final existingIndex = findImplantStorageIndex(fit, slotId, ref);
    if (existingIndex == null) return fit;

    final implants = fit.body.implants.toList();
    implants[existingIndex] = implants[existingIndex].copyWith(
      state: implants[existingIndex].state.toggle(FitItemState.online),
    );
    return fit.copyWith(body: fit.body.copyWith(implants: implants.toIList()));
  });

  Option<FitModuleItem> getImplantAsModule(FitStorage fit, int index) {
    if (index < 0 || index >= fit.body.implants.length) return const Option.none();
    final implant = fit.body.implants[index];
    return Option.of(
      FitModuleItem(itemId: implant.itemId, charge: const Option.none(), state: implant.state),
    );
  }

  Option<FitModuleItem> getBoosterAsModule(FitStorage fit, int slotId) {
    final booster = fit.body.boosters.firstWhereOrNull((entry) => entry.index == slotId);
    if (booster == null) return const Option.none();
    return Option.of(
      FitModuleItem(itemId: booster.itemId, charge: const Option.none(), state: booster.state),
    );
  }

  FitStorage toggleImplantSlot(FitStorage fit, FitModuleItem slot, int index) {
    if (index < 0 || index >= fit.body.implants.length) return fit;
    final implants = fit.body.implants.toList();
    implants[index] = implants[index].copyWith(state: slot.state.toggle(FitItemState.online));
    return fit.copyWith(body: fit.body.copyWith(implants: implants.toIList()));
  }

  FitStorage toggleBoosterSlot(FitStorage fit, FitModuleItem slot, int slotId) {
    final boosterIndex = fit.body.boosters.indexWhere((entry) => entry.index == slotId);
    if (boosterIndex < 0) return fit;
    final boosters = fit.body.boosters.toList();
    boosters[boosterIndex] = boosters[boosterIndex].copyWith(
      state: slot.state.toggle(FitItemState.online),
    );
    return fit.copyWith(body: fit.body.copyWith(boosters: boosters.toIList()));
  }

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
                  state: FitItemState.online,
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
      case SlotIdentifierImplant(:final index):
        await equipImplantForSlot(index, typeId, ref);
      case SlotIdentifierBooster(:final slotId):
        await setBooster(slotId, typeId);
      default:
        break;
    }
  }

  Future<void> toggleSlot(SlotIdentifier slotIdent, WidgetRef ref) async {
    if (slotIdent case SlotIdentifierImplant(:final index)) {
      await toggleImplantForSlot(index, ref);
      return;
    }

    await wrapped.update((fit) {
      final slotsInfo = ref.read(bundleCollectionGetSlotsProvider);
      if (slotsInfo == null) return fit;

      final slotOpt = getSlot(fit, slotIdent);
      if (slotOpt.isNone()) return fit;

      final slot = slotOpt.toNullable()!;
      final typeId = _resolveOriginTypeId(fit, slot.itemId);
      if (typeId == null) {
        final message =
            "Missing origin type for slot toggle: slotIdent=$slotIdent, itemId=${slot.itemId}";
        warning(message);
        if (kDebugMode) {
          throw StateError(message);
        }
        return fit;
      }

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
        case SlotIdentifierImplant(:final index):
          return toggleImplantSlot(fit, slot, index);
        case SlotIdentifierBooster(:final slotId):
          return toggleBoosterSlot(fit, slot, slotId);
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
      case SlotIdentifierImplant _:
        await clearImplants();
      case SlotIdentifierBooster _:
        await clearBoosters();
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

  Future<void> removeSlot(SlotIdentifier slotIdent, [WidgetRef? ref]) async {
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
      case SlotIdentifierFighter(:final index):
        await removeFighter(index);
      case SlotIdentifierService(:final index):
        await removeService(index);
      case SlotIdentifierDrone(:final index):
        await removeDrone(index);
      case SlotIdentifierImplant(:final index):
        if (ref != null) await removeImplantForSlot(index, ref);
      case SlotIdentifierBooster(:final slotId):
        await removeBooster(slotId);
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
        await removeSlot(slotIdent, ref);
    }
  }

  Future<void> clearSubsystemAdjusted(Ship ship) => wrapped.update((fit) {
    final cleared = fit.copyWith(
      body: fit.body.copyWith(
        slots: fit.body.slots.copyWith(subsystem: emptySlotList(fit.body.slots.subsystem.length)),
      ),
    );
    return applySubsystemResize(cleared, ship, (_) => null);
  });

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

      final (updatedFit, clonedSlot) = _cloneModuleItem(fit, fromSlot.toNullable()!);

      return updateSlot(updatedFit, toIdent, (_) => Option.of(clonedSlot));
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
      final (updatedFit, clonedSlot) = _cloneModuleItem(fit, fromSlot.toNullable()!);

      return updateSlot(updatedFit, targetIdent, (_) => Option.of(clonedSlot));
    });
  }

  Future<void> setDynamicAttributeFactor(int dynamicItemId, int attributeId, double factor) =>
      wrapped.update((fit) {
        final updatedFit = _updateDynamicItem(
          fit,
          dynamicItemId,
          (dynamicItem) => dynamicItem.copyWith(
            dynamicAttributes: dynamicItem.dynamicAttributes.add(attributeId, factor),
          ),
        );
        return updatedFit ?? fit;
      });

  Future<void> resetDynamicAttributes(int dynamicItemId) => wrapped.update((fit) {
    final updatedFit = _updateDynamicItem(
      fit,
      dynamicItemId,
      (dynamicItem) => dynamicItem.copyWith(
        dynamicAttributes: IMap.fromEntries(
          dynamicItem.dynamicAttributes.keys.map(
            (attributeId) => MapEntry<int, double>(attributeId, 1),
          ),
        ),
      ),
    );
    return updatedFit ?? fit;
  });

  Future<void> randomizeDynamicAttributes(int dynamicItemId) => wrapped.update((fit) {
    final dynamicItem = _dynamicItemForId(fit, dynamicItemId);
    if (dynamicItem == null) {
      warning("Missing dynamic item $dynamicItemId while randomizing fit item");
      return fit;
    }

    final dynamicMutator = ref
        .read(bundleCollectionProvider)
        ?.getDynamicMutator(dynamicItem.modifierTypeId);
    if (dynamicMutator == null) {
      warning(
        "Missing dynamic mutator ${dynamicItem.modifierTypeId} while randomizing fit item $dynamicItemId",
      );
      return fit;
    }

    return _storeDynamicItem(
      fit,
      dynamicItem.copyWith(
        dynamicAttributes: IMap.fromEntries(
          dynamicMutator.attributes.entries.map((entry) {
            final range = entry.value;
            final factor = range.min + (math.Random().nextDouble() * (range.max - range.min));
            return MapEntry(entry.key, factor);
          }),
        ),
      ),
    );
  });

  Future<void> convertSlotToDynamic(
    SlotIdentifier slotIdent,
    int modifierTypeId,
    WidgetRef ref,
  ) => wrapped.update((fit) {
    final slotOpt = getSlot(fit, slotIdent);
    if (slotOpt.isNone()) return fit;

    final slot = slotOpt.toNullable()!;
    if (slot.itemId is FitStorageItemIdDynamic) return fit;

    final originTypeId = _resolveOriginTypeId(fit, slot.itemId);
    if (originTypeId == null) return fit;

    final dynamicMutator = ref.read(bundleCollectionProvider)?.getDynamicMutator(modifierTypeId);
    if (dynamicMutator == null) return fit;
    if (!dynamicMutator.applicableTypes.contains(originTypeId)) return fit;

    final dynamicItemId = _allocateDynamicItemId(fit);
    final dynamicItem = FitDynamicItem(
      dynamicItemId: dynamicItemId,
      originTypeId: originTypeId,
      typeId: dynamicMutator.resultingTypeId,
      modifierTypeId: modifierTypeId,
      dynamicAttributes: IMap.fromEntries(
        dynamicMutator.attributes.keys.map((attributeId) => MapEntry<int, double>(attributeId, 1)),
      ),
    );
    final updatedFit = fit.copyWith(
      dynamicRegistry: fit.dynamicRegistry.copyWith(
        dynamicItems: fit.dynamicRegistry.dynamicItems.add(dynamicItemId, dynamicItem),
      ),
    );

    return updateSlot(
      updatedFit,
      slotIdent,
      (_) => Option.of(slot.copyWith(itemId: FitStorageItemId.dynamic(dynamicId: dynamicItemId))),
    );
  });

  Future<void> revertSlotFromDynamic(SlotIdentifier slotIdent) => wrapped.update((fit) {
    final slotOpt = getSlot(fit, slotIdent);
    if (slotOpt.isNone()) return fit;

    final slot = slotOpt.toNullable()!;
    return slot.itemId.when(
      item: (_) => fit,
      dynamic: (dynamicId) {
        final dynamicItem = fit.dynamicRegistry.dynamicItems[dynamicId];
        if (dynamicItem == null) return fit;
        return updateSlot(
          fit,
          slotIdent,
          (_) =>
              Option.of(slot.copyWith(itemId: FitStorageItemId.item(id: dynamicItem.originTypeId))),
        );
      },
    );
  });

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
    SlotIdentifierImplant(:final index) => getImplantAsModule(fit, index),
    SlotIdentifierBooster(:final slotId) => getBoosterAsModule(fit, slotId),
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
    Slots_GeneralSlot _,
  ) {
    if (slot.state == FitItemState.online) {
      return fit;
    }

    final updatedSubsystem = fit.body.slots.subsystem.replaceBy(
      type.index,
      (_) => Option.of(slot.copyWith(state: FitItemState.online)),
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

  FitStorage toggleDroneSlot(FitStorage fit, FitModuleItem _, int index) {
    if (index < 0 || index >= fit.body.drones.length) return fit;

    final drone = fit.body.drones[index];
    final newState = drone.state.toggleDrone();
    final drones = fit.body.drones.toList();
    drones[index] = drone.copyWith(state: newState);

    return fit.copyWith(body: fit.body.copyWith(drones: drones.toIList()));
  }

  Future<void> clearDrones() =>
      wrapped.update((fit) => fit.copyWith(body: fit.body.copyWith(drones: IList<FitDroneItem>())));

  Future<void> addFighter(int typeId) async {
    final fit = ref.read(fitProvider(fitId)).fit;
    final ship = ref.read(bundleCollectionGetShipProvider(fit.body.shipTypeId));
    final fighterType = ref.read(bundleCollectionGetTypeProvider(typeId));
    if (ship == null || fighterType == null) return;
    if (fit.body.fighters.length >= ship.fighterTubes) return;

    final category = _fighterCategoryFromGroupId(fighterType.groupId);
    if (category != null) {
      final categoryLimit = _fighterCategoryLimit(
        ref.read(nativeEmulatedShipProvider(fitId)),
        category,
      );
      if (categoryLimit > 0 && _fighterCategoryCount(fit, category) >= categoryLimit) {
        return;
      }
    }

    final groupId = fit.body.fighters.length;
    final quantity = await _resolveDefaultFighterQuantity(fit, typeId, groupId);
    if (quantity == null) return;

    await wrapped.update((currentFit) {
      final currentShip = ref.read(bundleCollectionGetShipProvider(currentFit.body.shipTypeId));
      if (currentFit.body.characterId != fit.body.characterId ||
          currentShip == null ||
          currentFit.body.fighters.length >= currentShip.fighterTubes) {
        return currentFit;
      }

      final fighters = currentFit.body.fighters.toList()
        ..add(
          FitFighterItem(
            itemId: FitStorageItemId.item(id: typeId),
            groupId: currentFit.body.fighters.length,
            quantity: quantity,
            fighterAbility: 0,
          ),
        );
      return currentFit.copyWith(
        body: currentFit.body.copyWith(fighters: _normalizeFighters(fighters)),
      );
    });
  }

  Future<void> clearFighters() => wrapped.update(
    (fit) => fit.copyWith(body: fit.body.copyWith(fighters: IList<FitFighterItem>())),
  );

  Future<void> removeFighter(int index) => wrapped.update((fit) {
    if (index < 0 || index >= fit.body.fighters.length) return fit;
    final fighters = fit.body.fighters.toList()..removeAt(index);
    return fit.copyWith(body: fit.body.copyWith(fighters: _normalizeFighters(fighters)));
  });

  Future<void> setFighterAbility(int index, int abilityMask) => wrapped.update((fit) {
    if (index < 0 || index >= fit.body.fighters.length) return fit;
    final fighters = fit.body.fighters.toList();
    fighters[index] = fighters[index].copyWith(fighterAbility: abilityMask);
    return fit.copyWith(body: fit.body.copyWith(fighters: fighters.toIList()));
  });

  Future<void> changeFighterAmount(int index, int newAmount) => wrapped.update((fit) {
    if (index < 0 || index >= fit.body.fighters.length) return fit;
    final fighters = fit.body.fighters.toList();
    if (newAmount <= 0) {
      fighters.removeAt(index);
      return fit.copyWith(body: fit.body.copyWith(fighters: _normalizeFighters(fighters)));
    }

    fighters[index] = fighters[index].copyWith(quantity: newAmount);
    return fit.copyWith(body: fit.body.copyWith(fighters: fighters.toIList()));
  });

  Future<void> changeFighterAmountBy(int index, int diff) => wrapped.update((fit) {
    if (index < 0 || index >= fit.body.fighters.length) return fit;
    final fighters = fit.body.fighters.toList();
    final newAmount = fighters[index].quantity + diff;
    if (newAmount <= 0) {
      fighters.removeAt(index);
      return fit.copyWith(body: fit.body.copyWith(fighters: _normalizeFighters(fighters)));
    }

    fighters[index] = fighters[index].copyWith(quantity: newAmount);
    return fit.copyWith(body: fit.body.copyWith(fighters: fighters.toIList()));
  });

  Future<void> toggleFighterAbilityBit(int index, int abilityBit) => wrapped.update((fit) {
    if (index < 0 || index >= fit.body.fighters.length) return fit;
    final fighters = fit.body.fighters.toList();
    final fighter = fighters[index];
    fighters[index] = fighter.copyWith(fighterAbility: fighter.fighterAbility ^ abilityBit);
    return fit.copyWith(body: fit.body.copyWith(fighters: fighters.toIList()));
  });

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

    // Subsystems can redefine the ship's slot topology. We intentionally keep
    // legacy behavior here: when the new layout shrinks, tail slots are dropped
    // outright so the resulting fit shape matches the deprecated fitter and the
    // native engine never sees modules in now-invalid slots.
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
