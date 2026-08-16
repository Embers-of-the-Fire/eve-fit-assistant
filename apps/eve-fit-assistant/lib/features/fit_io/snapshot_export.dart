import "dart:convert";
import "dart:math";

import "package:efa_constant/eve.dart";
import "package:efa_fit/efa_fit.dart";
import "package:efa_proto/fit.pb.dart" show TacticalMode;
import "package:efa_proto/utils.pb.dart" as utils_pb;
import "package:eve_fit_assistant/features/announcements/repository/announcement_repository.dart";
import "package:eve_fit_assistant/features/fit_io/text_export.dart";
import "package:eve_fit_assistant/native/api/output.dart" as native;
import "package:eve_fit_assistant/pages/fit/components/equipment/slot_row/related_values_logic.dart";
import "package:eve_fit_assistant/storage/character/manager.dart";
import "package:eve_fit_assistant/storage/character/schema.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/localization_db.dart";
import "package:eve_fit_assistant/utils/native.dart";
import "package:eve_fit_assistant/utils/native_convert.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fpdart/fpdart.dart";

class FitSnapshotExporter {
  const FitSnapshotExporter(this.ref);

  final WidgetRef ref;

  Future<String> export({required String fitId, required FitStorage fit}) async {
    final collection = ref.read(repoCollectionProvider);
    final names = await FitTypeNameResolver.load(ref, fit);
    final emulated = ref.read(nativeEmulatedShipProvider(fitId));
    final ship = collection?.getShip(fit.body.shipTypeId);

    final metaGroupNameIds = <int>{};
    final tacticalModeNameIds = <int>{};
    for (final typeId in _referencedTypeIds(fit)) {
      final type = collection?.getType(typeId);
      if (type != null && type.hasMetaGroupId()) {
        final metaGroup = collection?.getMetaGroup(type.metaGroupId);
        if (metaGroup != null) metaGroupNameIds.add(metaGroup.metaGroupName.id);
      }
    }
    for (final mode in ship?.tacticalModes ?? const <TacticalMode>[]) {
      final type = collection?.getType(mode.typeId);
      if (type != null) tacticalModeNameIds.add(type.typeName.id);
    }
    final localization = await ref.read(localizationDbServiceProvider.future);
    final extraNames =
        await localization?.localizedNames({...metaGroupNameIds, ...tacticalModeNameIds}, "en") ??
        const <int, String>{};

    SnapshotTypeData typeData(int typeId) {
      final type = collection?.getType(typeId);
      SnapshotMetaGroupData? metaGroupData;
      if (type != null && type.hasMetaGroupId()) {
        final metaGroup = collection?.getMetaGroup(type.metaGroupId);
        if (metaGroup != null) {
          metaGroupData = SnapshotMetaGroupData(
            id: metaGroup.metaGroupId,
            names: {
              "en": extraNames[metaGroup.metaGroupName.id] ?? "Meta ${metaGroup.metaGroupId}",
            },
            icon: _iconData(metaGroup.icon),
          );
        }
      }
      return SnapshotTypeData(
        typeId: typeId,
        names: {"en": names.typeName(typeId)},
        icon: type == null ? null : _iconData(type.icon),
        metaGroup: metaGroupData,
      );
    }

    native.Item? emulatedModule(bool Function(native.OutSlotType) matchType, int index) {
      for (final item in emulated?.modules ?? const <native.Item>[]) {
        if (matchType(item.slot.slotType) && item.slot.index == index) return item;
      }
      return null;
    }

    SnapshotModuleData? moduleData(
      FitModuleItem item, {
      required SnapshotRack? rack,
      required int index,
    }) {
      final dynamicItem = item.itemId.when<FitDynamicItem?>(
        item: (_) => null,
        dynamic: (dynamicId) => fit.dynamicRegistry.dynamicItems[dynamicId],
      );
      final displayId = item.itemId.when(
        item: (id) => id,
        dynamic: (dynamicId) => dynamicItem?.typeId,
      );
      final originId = item.itemId.when(
        item: (id) => id,
        dynamic: (dynamicId) => dynamicItem?.originTypeId,
      );
      final resolvedId = displayId ?? originId;
      if (resolvedId == null) return null;

      final emulatedItem = rack == null
          ? null
          : emulatedModule((type) => _matchesRack(type, rack), index);

      final charge = item.charge.toNullable();
      final highInfo = rack == SnapshotRack.high
          ? collection?.slots.highSlots[originId ?? resolvedId]
          : null;

      return SnapshotModuleData(
        type: typeData(resolvedId),
        state: item.state.protobufImpl,
        charge: charge == null
            ? null
            : SnapshotChargeData(
                type: typeData(charge.typeId),
                quantity: emulatedItem?.getAttribute(EveConstExtendedAttrID.chargeAmount).round(),
              ),
        isTurret: highInfo?.isTurret ?? false,
        isLauncher: highInfo?.isLauncher ?? false,
        originType: displayId != null && originId != null && displayId != originId
            ? typeData(originId)
            : null,
        relatedValues: [
          if (emulatedItem != null)
            for (final segment in collectSlotRelatedValues(emulatedItem))
              SnapshotDisplayValueData(text: segment.text, attributeId: segment.iconAttributeId),
        ],
      );
    }

    var turretHardpoints = ship?.turretSlots ?? 0;
    var launcherHardpoints = ship?.launcherSlots ?? 0;
    for (final slotOpt in fit.body.slots.subsystem) {
      final item = slotOpt.toNullable();
      if (item == null) continue;
      final originId = item.itemId.when(
        item: (id) => id,
        dynamic: (dynamicId) => fit.dynamicRegistry.dynamicItems[dynamicId]?.originTypeId,
      );
      if (originId == null) continue;
      final def = collection?.getSubsystem(originId);
      if (def == null) continue;
      turretHardpoints += def.turretSlots;
      launcherHardpoints += def.launcherSlots;
    }

    final appVersion = await ref
        .read(appVersionProvider.future)
        .then((version) => version, onError: (_) => "unknown");

    final builder = FitSnapshotBuilder(
      fitName: fit.metadata.name,
      description: fit.metadata.description,
      ship: typeData(fit.body.shipTypeId),
      layout: SnapshotShipLayoutData(
        highSlots: max(ship?.highSlots ?? 0, fit.body.slots.high.length),
        mediumSlots: max(ship?.mediumSlots ?? 0, fit.body.slots.medium.length),
        lowSlots: max(ship?.lowSlots ?? 0, fit.body.slots.low.length),
        rigSlots: max(ship?.rigSlots ?? 0, fit.body.slots.rig.length),
        subsystemSlots: max(ship?.subsystemSlots ?? 0, fit.body.slots.subsystem.length),
        serviceSlots: max(ship?.serviceSlots ?? 0, fit.body.slots.service.length),
        turretHardpoints: turretHardpoints,
        launcherHardpoints: launcherHardpoints,
        fighterTubes: ship?.fighterTubes ?? 0,
      ),
      character: _characterData(fit),
      damageProfile: SnapshotDamageProfile(
        em: fit.body.damageProfile.em,
        thermal: fit.body.damageProfile.thermal,
        kinetic: fit.body.damageProfile.kinetic,
        explosive: fit.body.damageProfile.explosive,
      ),
      lastModified: DateTime.fromMillisecondsSinceEpoch(fit.metadata.lastModified),
      generator: "eve-fit-assistant/$appVersion",
      checkoutId: fit.metadata.checkoutRef.checkoutId,
      serverId: fit.metadata.checkoutRef.serverId,
      availableTacticalModes: [
        for (final mode in ship?.tacticalModes ?? const <TacticalMode>[])
          SnapshotTacticalModeData(type: typeData(mode.typeId), variant: mode.variant),
      ],
    );

    final racks = [
      (SnapshotRack.high, fit.body.slots.high),
      (SnapshotRack.medium, fit.body.slots.medium),
      (SnapshotRack.low, fit.body.slots.low),
      (SnapshotRack.rig, fit.body.slots.rig),
      (SnapshotRack.service, fit.body.slots.service),
    ];
    for (final (rack, slots) in racks) {
      for (var index = 0; index < slots.length; index++) {
        final item = slots[index].toNullable();
        if (item == null) continue;
        final data = moduleData(item, rack: rack, index: index);
        if (data != null) builder.setModule(rack, index, data);
      }
    }

    for (var index = 0; index < fit.body.slots.subsystem.length; index++) {
      final item = fit.body.slots.subsystem[index].toNullable();
      if (item == null) continue;
      final data = moduleData(item, rack: null, index: index);
      if (data == null) continue;
      final originId = item.itemId.when(
        item: (id) => id,
        dynamic: (dynamicId) => fit.dynamicRegistry.dynamicItems[dynamicId]?.originTypeId,
      );
      final subsystemType =
          collection?.getSubsystem(originId ?? 0)?.subsystemType ?? Subsystem_SubsystemType.UNKNOWN;
      builder.setSubsystem(index, subsystemType, data);
    }

    if (fit.body.slots.tacticalMode case Some(:final value)) {
      final mode = ship?.tacticalModes.where((mode) => mode.typeId == value).firstOrNull;
      if (mode != null) {
        builder.setTacticalMode(
          SnapshotTacticalModeData(type: typeData(mode.typeId), variant: mode.variant),
        );
      }
    }

    for (final drone in fit.body.drones) {
      final typeId = drone.itemId.when(
        item: (id) => id,
        dynamic: (dynamicId) => fit.dynamicRegistry.dynamicItems[dynamicId]?.typeId,
      );
      if (typeId == null) continue;
      builder.addDrone(
        SnapshotDroneData(
          type: typeData(typeId),
          state: drone.state.protobufImpl,
          quantity: drone.quantity,
        ),
      );
    }

    for (final fighter in fit.body.fighters) {
      final dynamicItem = fighter.itemId.when<FitDynamicItem?>(
        item: (_) => null,
        dynamic: (dynamicId) => fit.dynamicRegistry.dynamicItems[dynamicId],
      );
      final displayId = fighter.itemId.when(
        item: (id) => id,
        dynamic: (dynamicId) => dynamicItem?.typeId,
      );
      final originId = fighter.itemId.when(
        item: (id) => id,
        dynamic: (dynamicId) => dynamicItem?.originTypeId,
      );
      final resolvedId = displayId ?? originId;
      if (resolvedId == null) continue;

      final groupType = collection?.getType(originId ?? resolvedId);
      final emulatedFighter = (emulated?.modules ?? const <native.Item>[])
          .where(
            (item) => switch (item.slot.slotType) {
              native.OutSlotType_Fighter(:final groupId) => groupId == fighter.groupId,
              _ => false,
            },
          )
          .firstOrNull;
      builder.addFighter(
        SnapshotFighterData(
          type: typeData(resolvedId),
          state: Slots_SlotState.ACTIVE,
          quantity: fighter.quantity,
          maxSquadronSize:
              emulatedFighter?.getAttribute(EveConstAttrID.fighterSquadronMaxSize).round() ??
              fighter.quantity,
          group: _squadronGroup(groupType?.groupId),
          abilities: [
            if (fighter.fighterAbility & 0x01 != 0) SnapshotFighter_Ability.TURRET,
            if (fighter.fighterAbility & 0x02 != 0) SnapshotFighter_Ability.MISSILES,
            if (fighter.fighterAbility & 0x04 != 0) SnapshotFighter_Ability.ATTACK_MISSILES,
            if (fighter.fighterAbility & 0x08 != 0) SnapshotFighter_Ability.BOMB,
          ],
        ),
      );
    }

    for (final implant in fit.body.implants) {
      final typeId = implant.itemId.when(
        item: (id) => id,
        dynamic: (dynamicId) => fit.dynamicRegistry.dynamicItems[dynamicId]?.typeId,
      );
      if (typeId == null) continue;
      final slotIndex = collection?.slots.implantSlots[typeId]?.slotIndex;
      if (slotIndex == null) continue;
      builder.setImplant(
        slotIndex,
        SnapshotModuleData(type: typeData(typeId), state: implant.state.protobufImpl),
      );
    }

    final usedBoosterSlots = <int>{};
    for (final booster in fit.body.boosters) {
      final typeId = booster.itemId.when(
        item: (id) => id,
        dynamic: (dynamicId) => fit.dynamicRegistry.dynamicItems[dynamicId]?.typeId,
      );
      if (typeId == null) continue;
      final slotIndex = collection?.slots.boosterSlots[typeId]?.slotIndex ?? booster.index;
      if (!usedBoosterSlots.add(slotIndex)) continue;
      builder.addBooster(
        SnapshotBoosterData(
          slotIndex: slotIndex,
          type: typeData(typeId),
          state: booster.state.protobufImpl,
        ),
      );
    }

    if (emulated != null) {
      builder.setStatistics(_statistics(emulated));
    }

    return base64Encode(encodeFitSnapshot(builder.build()));
  }

  SnapshotCharacterData _characterData(FitStorage fit) {
    final characterId = fit.body.characterId;
    return switch (characterId) {
      predefinedMaxCharacterId => const SnapshotCharacterData.builtin(
        SnapshotBuiltinCharacter.all5,
        names: {"en": "All 5"},
      ),
      predefinedZeroCharacterId => const SnapshotCharacterData.builtin(
        SnapshotBuiltinCharacter.all0,
        names: {"en": "All 0"},
      ),
      predefinedAlphaMaxCharacterId => const SnapshotCharacterData.builtin(
        SnapshotBuiltinCharacter.alphaMax,
        names: {"en": "Alpha Max"},
      ),
      _ => SnapshotCharacterData.custom(
        characterId: characterId,
        names: {
          "en":
              ref.read(characterRegistryManagerProvider).characters[characterId]?.name ??
              characterId,
        },
      ),
    };
  }

  SnapshotStatistics _statistics(native.Ship ship) {
    final hull = ship.hull;
    final character = ship.character;

    final depletesIn = hull.getAttribute(EveConstExtendedAttrID.capacitorDepletesIn);
    final isStable = depletesIn <= 0;
    final peakLoad = hull.getAttribute(EveConstExtendedAttrID.capacitorPeakLoad);
    final peakDelta = hull.getAttribute(EveConstExtendedAttrID.capacitorPeakDelta);
    final rechargeTimeMs = hull.getAttribute(EveConstAttrID.rechargeRate);
    final capacity = hull.getAttribute(EveConstAttrID.capacitorCapacity);
    final stablePercent = isStable
        ? capacitorStableAt(
            capacity: capacity,
            targetRechargeRage: peakLoad,
            rechargeTime: rechargeTimeMs,
          ).clamp(0.0, 100.0)
        : null;

    final fighterDps = hull.getAttribute(EveConstExtendedAttrID.fighterDamagePerSecond);
    final fighterVolley = ship.modules
        .where((item) => item.slot.slotType is native.OutSlotType_Fighter)
        .fold<double>(
          0,
          (sum, item) =>
              sum +
              item.getAttribute(EveConstExtendedAttrID.fighterDamageMissiles) +
              item.getAttribute(EveConstExtendedAttrID.fighterDamageAttackTurret) +
              item.getAttribute(EveConstExtendedAttrID.fighterDamageAttackMissile),
        );

    SnapshotStatistics_DefenseLayer defenseLayer({
      required int hpAttribute,
      required int ehpAttribute,
      required int emResonance,
      required int thermalResonance,
      required int kineticResonance,
      required int explosiveResonance,
    }) => SnapshotStatistics_DefenseLayer(
      hp: hull.getAttribute(hpAttribute),
      ehp: hull.getAttribute(ehpAttribute),
      resistances: DamageProfile(
        em: 1 - hull.getAttribute(emResonance, 1),
        thermal: 1 - hull.getAttribute(thermalResonance, 1),
        kinetic: 1 - hull.getAttribute(kineticResonance, 1),
        explosive: 1 - hull.getAttribute(explosiveResonance, 1),
      ),
    );

    final holds = <SnapshotStatistics_Cargo_Hold>[
      for (final (kind, attribute) in [
        (SnapshotStatistics_Cargo_HoldKind.FLEET_HANGAR, EveConstAttrID.fleetHangarCapacity),
        (
          SnapshotStatistics_Cargo_HoldKind.SHIP_MAINTENANCE_BAY,
          EveConstAttrID.shipMaintenanceBayCapacity,
        ),
        (SnapshotStatistics_Cargo_HoldKind.MINING_HOLD, EveConstAttrID.generalMiningHoldCapacity),
        (SnapshotStatistics_Cargo_HoldKind.GAS_HOLD, EveConstAttrID.specialGasHoldCapacity),
        (SnapshotStatistics_Cargo_HoldKind.MINERAL_HOLD, EveConstAttrID.specialMineralHoldCapacity),
        (SnapshotStatistics_Cargo_HoldKind.ICE_HOLD, EveConstAttrID.specialIceHoldCapacity),
        (
          SnapshotStatistics_Cargo_HoldKind.COMMAND_CENTER_HOLD,
          EveConstAttrID.specialCommandCenterHoldCapacity,
        ),
        (
          SnapshotStatistics_Cargo_HoldKind.PLANETARY_COMMODITIES_HOLD,
          EveConstAttrID.specialPlanetaryCommoditiesHoldCapacity,
        ),
        (SnapshotStatistics_Cargo_HoldKind.FUEL_BAY, EveConstAttrID.specialFuelBayCapacity),
      ])
        if (hull.getAttribute(attribute) != 0)
          SnapshotStatistics_Cargo_Hold(kind: kind, capacityM3: hull.getAttribute(attribute)),
    ];

    return SnapshotStatistics(
      capacitor: SnapshotStatistics_Capacitor(
        isStable: isStable,
        stableFraction: stablePercent == null ? null : stablePercent / 100,
        peakUseRate: peakLoad,
        peakRechargeRate: peakLoad + peakDelta,
        capacityGj: capacity,
        rechargeTimeS: rechargeTimeMs / 1000,
        depletesInS: isStable ? null : depletesIn,
      ),
      weapons: SnapshotStatistics_Weapons(
        dpsTotal:
            hull.getAttribute(EveConstExtendedAttrID.damagePerSecondWithoutReload) + fighterDps,
        dpsWithReload:
            hull.getAttribute(EveConstExtendedAttrID.damagePerSecondWithReload) + fighterDps,
        alphaVolley: hull.getAttribute(EveConstExtendedAttrID.damageAlpha) + fighterVolley,
      ),
      resources: SnapshotStatistics_Resources(
        cpuUsed:
            hull.getAttribute(EveConstAttrID.cpuOutput) -
            hull.getAttribute(EveConstExtendedAttrID.cpuFree),
        cpuTotal: hull.getAttribute(EveConstAttrID.cpuOutput),
        powergridUsed:
            hull.getAttribute(EveConstAttrID.powerOutput) -
            hull.getAttribute(EveConstExtendedAttrID.powerFree),
        powergridTotal: hull.getAttribute(EveConstAttrID.powerOutput),
        calibrationUsed: hull.getAttribute(EveConstExtendedAttrID.upgradeUsed),
        calibrationTotal: hull.getAttribute(EveConstAttrID.upgradeCapacity),
        droneBandwidthUsed: hull.getAttribute(EveConstAttrID.droneBandwidthLoad),
        droneBandwidthTotal: hull.getAttribute(EveConstAttrID.droneBandwidth),
      ),
      shield: defenseLayer(
        hpAttribute: EveConstAttrID.shieldCapacity,
        ehpAttribute: EveConstExtendedAttrID.shieldEhp,
        emResonance: EveConstAttrID.shieldEmDamageResonance,
        thermalResonance: EveConstAttrID.shieldThermalDamageResonance,
        kineticResonance: EveConstAttrID.shieldKineticDamageResonance,
        explosiveResonance: EveConstAttrID.shieldExplosiveDamageResonance,
      ),
      armor: defenseLayer(
        hpAttribute: EveConstAttrID.armorHP,
        ehpAttribute: EveConstExtendedAttrID.armorEhp,
        emResonance: EveConstAttrID.armorEmDamageResonance,
        thermalResonance: EveConstAttrID.armorThermalDamageResonance,
        kineticResonance: EveConstAttrID.armorKineticDamageResonance,
        explosiveResonance: EveConstAttrID.armorExplosiveDamageResonance,
      ),
      hull: defenseLayer(
        hpAttribute: EveConstAttrID.hp,
        ehpAttribute: EveConstExtendedAttrID.hullEhp,
        emResonance: EveConstAttrID.emDamageResonance,
        thermalResonance: EveConstAttrID.thermalDamageResonance,
        kineticResonance: EveConstAttrID.kineticDamageResonance,
        explosiveResonance: EveConstAttrID.explosiveDamageResonance,
      ),
      mobility: SnapshotStatistics_Mobility(
        maxVelocityMs: hull.getAttribute(EveConstAttrID.maxVelocity),
        warpSpeedAuS: hull.getAttribute(EveConstExtendedAttrID.warpSpeed),
        alignTimeS: hull.getAttribute(EveConstExtendedAttrID.alignTime),
        signatureRadiusM: hull.getAttribute(EveConstAttrID.signatureRadius),
      ),
      targeting: SnapshotStatistics_Targeting(
        maxTargetRangeM: hull.getAttribute(EveConstAttrID.maxTargetRange),
        scanResolutionMm: hull.getAttribute(EveConstAttrID.scanResolution),
        maxLockedTargets: hull.getAttribute(EveConstAttrID.maxLockedTargets).round(),
        radarStrength: hull.getAttribute(EveConstAttrID.scanRadarStrength),
        ladarStrength: hull.getAttribute(EveConstAttrID.scanLadarStrength),
        magnetometricStrength: hull.getAttribute(EveConstAttrID.scanMagnetometricStrength),
        gravimetricStrength: hull.getAttribute(EveConstAttrID.scanGravimetricStrength),
      ),
      drones: SnapshotStatistics_Drones(
        maxActiveDrones: character.getAttribute(EveConstAttrID.maxActiveDrones).round(),
        controlRangeM: character.getAttribute(EveConstAttrID.droneControlDistance),
        bayCapacityM3: hull.getAttribute(EveConstAttrID.droneCapacity),
        bayUsedM3: hull.getAttribute(EveConstExtendedAttrID.droneCapacityLoad),
      ),
      cargo: SnapshotStatistics_Cargo(
        massKg: hull.getAttribute(EveConstExtendedAttrID.totalMass),
        capacityM3: hull.getAttribute(EveConstAttrID.capacity),
        holds: holds,
      ),
    );
  }
}

bool _matchesRack(native.OutSlotType type, SnapshotRack rack) => switch (rack) {
  SnapshotRack.high => type is native.OutSlotType_High,
  SnapshotRack.medium => type is native.OutSlotType_Medium,
  SnapshotRack.low => type is native.OutSlotType_Low,
  SnapshotRack.rig => type is native.OutSlotType_Rig,
  SnapshotRack.service => type is native.OutSlotType_Service,
};

SnapshotFighter_SquadronGroup _squadronGroup(int? groupId) => switch (groupId) {
  1652 || 4777 => SnapshotFighter_SquadronGroup.LIGHT,
  1537 || 4778 => SnapshotFighter_SquadronGroup.SUPPORT,
  1653 || 4779 => SnapshotFighter_SquadronGroup.HEAVY,
  _ => SnapshotFighter_SquadronGroup.LIGHT,
};

SnapshotIcon? _iconData(utils_pb.Icon icon) {
  if (!icon.hasGraphicId() && !icon.hasIconId()) return null;
  return SnapshotIcon(
    graphicId: icon.hasGraphicId() ? icon.graphicId : null,
    iconId: icon.hasIconId() ? icon.iconId : null,
  );
}

Set<int> _referencedTypeIds(FitStorage fit) {
  final typeIds = <int>{fit.body.shipTypeId};
  void collect(FitStorageItemId itemId) {
    typeIds.add(
      itemId.when(
        item: (id) => id,
        dynamic: (dynamicId) =>
            fit.dynamicRegistry.dynamicItems[dynamicId]?.originTypeId ??
            fit.dynamicRegistry.dynamicItems[dynamicId]?.typeId ??
            dynamicId,
      ),
    );
  }

  for (final slots in [
    fit.body.slots.low,
    fit.body.slots.medium,
    fit.body.slots.high,
    fit.body.slots.rig,
    fit.body.slots.subsystem,
    fit.body.slots.service,
  ]) {
    for (final slotOpt in slots) {
      slotOpt.map((slot) {
        collect(slot.itemId);
        slot.charge.map((charge) => typeIds.add(charge.typeId));
      });
    }
  }
  if (fit.body.slots.tacticalMode case Some(:final value)) {
    typeIds.add(value);
  }
  for (final drone in fit.body.drones) {
    collect(drone.itemId);
  }
  for (final fighter in fit.body.fighters) {
    collect(fighter.itemId);
  }
  for (final implant in fit.body.implants) {
    collect(implant.itemId);
  }
  for (final booster in fit.body.boosters) {
    collect(booster.itemId);
  }
  return typeIds;
}
