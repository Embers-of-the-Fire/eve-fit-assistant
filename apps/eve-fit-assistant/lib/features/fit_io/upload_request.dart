import "dart:math";

import "package:efa_constant/eve.dart";
import "package:efa_proto/fit.pb.dart";
import "package:efa_proto/fit_request.pb.dart";
import "package:efa_proto/fit_snapshot.pb.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/account/providers.dart";
import "package:eve_fit_assistant/features/announcements/repository/announcement_repository.dart";
import "package:eve_fit_assistant/features/fit_io/snapshot_upload_api.dart";
import "package:eve_fit_assistant/native/api/output.dart" as native;
import "package:eve_fit_assistant/storage/character/manager.dart";
import "package:eve_fit_assistant/storage/character/schema.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart" hide FitDynamicItem;
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/utils/native.dart";
import "package:eve_fit_assistant/utils/native_convert.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fpdart/fpdart.dart";

/// The data repository has no active checkout/snapshot yet, so an upload
/// request cannot be addressed to a registered engine-data snapshot.
class FitUploadNotReadyException implements Exception {
  const FitUploadNotReadyException();

  @override
  String toString() => "FitUploadNotReadyException";
}

/// The whole "build request + submit via the account session" upload
/// operation, exposed as a provider so widget tests can exercise the upload
/// flow without the data repository or the network.
typedef FitSnapshotUploadFn =
    Future<FitPostSubmitResult> Function(
      WidgetRef ref, {
      required String fitId,
      required FitStorage fit,
    });

final fitSnapshotUploadFnProvider = Provider<FitSnapshotUploadFn>((Ref ref) => _submitFitSnapshot);

Future<FitPostSubmitResult> _submitFitSnapshot(
  WidgetRef ref, {
  required String fitId,
  required FitStorage fit,
}) async {
  final request = await FitUploadRequestBuilder(ref).build(fitId: fitId, fit: fit);
  final session = await ref.read(platformSessionProvider.future);
  return session.authed(
    (dio) =>
        ref.read(fitSnapshotUploadApiProvider).submit(request, dio: dio, origin: session.origin),
  );
}

/// Builds the [FitUploadRequest] for the remote fit storage service from the
/// app's providers (repository collection, active snapshot, character skills,
/// app version, emulated ship).
class FitUploadRequestBuilder {
  const FitUploadRequestBuilder(this.ref);

  final WidgetRef ref;

  Future<FitUploadRequest> build({required String fitId, required FitStorage fit}) async {
    final collection = ref.read(repoCollectionProvider);
    final snapshotHash = ref.read(activeSnapshotHashProvider).toNullable();
    if (collection == null || snapshotHash == null) {
      throw const FitUploadNotReadyException();
    }

    final emulated = ref.read(nativeEmulatedShipProvider(fitId));
    final characterName = switch (fit.body.characterId) {
      predefinedMaxCharacterId => "All 5",
      predefinedZeroCharacterId => "All 0",
      predefinedAlphaMaxCharacterId => "Alpha Max",
      final characterId =>
        ref.read(characterRegistryManagerProvider).characters[characterId]?.name ?? characterId,
    };

    final appVersion = await ref
        .read(appVersionProvider.future)
        .then((version) => version, onError: (_) => "unknown");
    final skills = await ref
        .read(characterRegistryManagerProvider.notifier)
        .resolveCharacterSkills(fit.body.characterId, collection.getSkillTypeIds());

    return buildFitUploadRequest(
      fit: fit,
      snapshotHash: snapshotHash,
      generator: "eve-fit-assistant/$appVersion",
      skills: skills,
      characterName: characterName,
      collection: collection,
      emulated: emulated,
    );
  }
}

/// Pure mapping from [FitStorage] to the upload wire format
/// (`data/schema/fit_request.proto`). The worker re-applies the app's state
/// conventions server-side (passive rigs/implants/boosters are ignored,
/// subsystem modules are fed online), so raw slot states are sent as-is.
FitUploadRequest buildFitUploadRequest({
  required FitStorage fit,
  required String snapshotHash,
  required String generator,
  required Map<int, int> skills,
  required String characterName,
  RepoCollectionService? collection,
  native.Ship? emulated,
}) {
  final ship = collection?.getShip(fit.body.shipTypeId);

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

  final modules = <FitModule>[];
  void collectRack(IList<Option<FitModuleItem>> slots, SlotType slotType) {
    for (var index = 0; index < slots.length; index++) {
      final item = slots[index].toNullable();
      if (item == null) continue;
      final module = FitModule(
        slotType: slotType,
        index: index,
        state: item.state.protobufImpl,
        chargeTypeId: item.charge.toNullable()?.typeId,
      );
      final resolved = item.itemId.when(
        item: (id) {
          module.typeId = id;
          return id;
        },
        dynamic: (dynamicId) {
          final dynamicItem = fit.dynamicRegistry.dynamicItems[dynamicId];
          if (dynamicItem == null) {
            warning(
              "Skipping ${slotType.name} module $index with missing dynamic item $dynamicId "
              "in fit ${fit.metadata.fitId}",
            );
            return null;
          }
          module.dynamicId = dynamicId;
          return dynamicItem.originTypeId;
        },
      );
      if (resolved == null) continue;
      if (slotType == SlotType.SUBSYSTEM) {
        final subsystemType = collection?.getSubsystem(resolved)?.subsystemType;
        if (subsystemType == null) {
          warning(
            "Skipping subsystem module $index: cannot resolve subsystem type for $resolved "
            "in fit ${fit.metadata.fitId}",
          );
          continue;
        }
        module.subsystemType = subsystemType;
      }
      modules.add(module);
    }
  }

  collectRack(fit.body.slots.high, SlotType.HIGH);
  collectRack(fit.body.slots.medium, SlotType.MEDIUM);
  collectRack(fit.body.slots.low, SlotType.LOW);
  collectRack(fit.body.slots.rig, SlotType.RIG);
  collectRack(fit.body.slots.subsystem, SlotType.SUBSYSTEM);
  collectRack(fit.body.slots.service, SlotType.SERVICE);

  final drones = <FitDrone>[];
  for (final drone in fit.body.drones) {
    final typeId = drone.itemId.when(
      item: (id) => id,
      dynamic: (dynamicId) {
        final typeId = fit.dynamicRegistry.dynamicItems[dynamicId]?.typeId;
        if (typeId == null) {
          warning(
            "Skipping drone with missing dynamic item $dynamicId in fit ${fit.metadata.fitId}",
          );
        }
        return typeId;
      },
    );
    if (typeId == null) continue;
    drones.add(FitDrone(typeId: typeId, state: drone.state.protobufImpl, quantity: drone.quantity));
  }

  final fighters = <FitFighter>[];
  for (final fighter in fit.body.fighters) {
    final displayId = fighter.itemId.when(
      item: (id) => id,
      dynamic: (dynamicId) => fit.dynamicRegistry.dynamicItems[dynamicId]?.typeId,
    );
    final originId = fighter.itemId.when(
      item: (id) => id,
      dynamic: (dynamicId) => fit.dynamicRegistry.dynamicItems[dynamicId]?.originTypeId,
    );
    final resolvedId = displayId ?? originId;
    if (resolvedId == null) {
      warning(
        "Skipping fighter with missing dynamic item ${fighter.itemId.asId} "
        "in fit ${fit.metadata.fitId}",
      );
      continue;
    }

    final groupType = collection?.getType(originId ?? resolvedId);
    final emulatedFighter = (emulated?.modules ?? const <native.Item>[])
        .where(
          (item) => switch (item.slot.slotType) {
            native.OutSlotType_Fighter(:final groupId) => groupId == fighter.groupId,
            _ => false,
          },
        )
        .firstOrNull;
    fighters.add(
      FitFighter(
        typeId: resolvedId,
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

  final implants = <FitImplant>[];
  for (final implant in fit.body.implants) {
    final typeId = implant.itemId.when(
      item: (id) => id,
      dynamic: (dynamicId) {
        final typeId = fit.dynamicRegistry.dynamicItems[dynamicId]?.typeId;
        if (typeId == null) {
          warning(
            "Skipping implant with missing dynamic item $dynamicId in fit ${fit.metadata.fitId}",
          );
        }
        return typeId;
      },
    );
    if (typeId == null) continue;
    final slotIndex = collection?.slots.implantSlots[typeId]?.slotIndex;
    if (slotIndex == null) {
      warning("Skipping implant $typeId with unknown slot index in fit ${fit.metadata.fitId}");
      continue;
    }
    implants.add(
      FitImplant(slotIndex: slotIndex, typeId: typeId, state: implant.state.protobufImpl),
    );
  }

  final boosters = <FitBooster>[];
  final usedBoosterSlots = <int>{};
  for (final booster in fit.body.boosters) {
    final typeId = booster.itemId.when(
      item: (id) => id,
      dynamic: (dynamicId) {
        final typeId = fit.dynamicRegistry.dynamicItems[dynamicId]?.typeId;
        if (typeId == null) {
          warning(
            "Skipping booster with missing dynamic item $dynamicId in fit ${fit.metadata.fitId}",
          );
        }
        return typeId;
      },
    );
    if (typeId == null) continue;
    final slotIndex = collection?.slots.boosterSlots[typeId]?.slotIndex ?? booster.index;
    if (!usedBoosterSlots.add(slotIndex)) continue;
    boosters.add(
      FitBooster(slotIndex: slotIndex, typeId: typeId, state: booster.state.protobufImpl),
    );
  }

  final referencedDynamicIds = collectReferencedDynamicItemIds(fit);
  final selectedMode = fit.body.slots.tacticalMode.toNullable();
  final isKnownMode =
      selectedMode != null &&
      (ship?.tacticalModes ?? const <TacticalMode>[]).any((mode) => mode.typeId == selectedMode);

  return FitUploadRequest(
    serverId: fit.metadata.checkoutRef.serverId,
    snapshotHash: snapshotHash,
    fitName: fit.metadata.name,
    description: fit.metadata.description.isEmpty ? null : fit.metadata.description,
    lastModifiedMs: Int64(fit.metadata.lastModified),
    generator: generator,
    fit: FitState(
      shipTypeId: fit.body.shipTypeId,
      layout: SnapshotShipLayout(
        highSlots: max(ship?.highSlots ?? 0, fit.body.slots.high.length),
        mediumSlots: max(ship?.mediumSlots ?? 0, fit.body.slots.medium.length),
        lowSlots: max(ship?.lowSlots ?? 0, fit.body.slots.low.length),
        rigSlots: max(ship?.rigSlots ?? 0, fit.body.slots.rig.length),
        subsystemSlots: exportSubsystemSlotCount(ship?.subsystemSlots, fit.body.slots.subsystem),
        serviceSlots: max(ship?.serviceSlots ?? 0, fit.body.slots.service.length),
        turretHardpoints: turretHardpoints,
        launcherHardpoints: launcherHardpoints,
        fighterTubes: ship?.fighterTubes ?? 0,
      ),
      availableTacticalModes: [
        for (final mode in ship?.tacticalModes ?? const <TacticalMode>[])
          FitTacticalModeRef(typeId: mode.typeId, variant: mode.variant),
      ],
      tacticalModeTypeId: isKnownMode ? selectedMode : null,
      modules: modules,
      drones: drones,
      fighters: fighters,
      implants: implants,
      boosters: boosters,
      skills: [for (final entry in skills.entries) FitSkill(typeId: entry.key, level: entry.value)],
      damageProfile: DamageProfile(
        em: fit.body.damageProfile.em,
        thermal: fit.body.damageProfile.thermal,
        kinetic: fit.body.damageProfile.kinetic,
        explosive: fit.body.damageProfile.explosive,
      ),
      dynamicItems: [
        for (final entry in fit.dynamicRegistry.dynamicItems.entries)
          if (referencedDynamicIds.contains(entry.key))
            FitDynamicItem(
              dynamicId: entry.key,
              baseTypeId: entry.value.originTypeId,
              typeId: entry.value.typeId,
              attributes: [
                for (final attribute in entry.value.dynamicAttributes.entries)
                  FitDynamicAttribute(attributeId: attribute.key, value: attribute.value),
              ],
            ),
      ],
      character: switch (fit.body.characterId) {
        predefinedMaxCharacterId => FitCharacter(names: [const MapEntry("en", "All 5")]),
        predefinedZeroCharacterId => FitCharacter(names: [const MapEntry("en", "All 0")]),
        predefinedAlphaMaxCharacterId => FitCharacter(names: [const MapEntry("en", "Alpha Max")]),
        final characterId => FitCharacter(
          characterId: characterId,
          names: [MapEntry("en", characterName)],
        ),
      },
    ),
  );
}

SnapshotFighter_SquadronGroup _squadronGroup(int? groupId) => switch (groupId) {
  EveConstGroupId.lightFighter ||
  EveConstGroupId.structureLightFighter => SnapshotFighter_SquadronGroup.LIGHT,
  EveConstGroupId.supportFighter ||
  EveConstGroupId.structureSupportFighter => SnapshotFighter_SquadronGroup.SUPPORT,
  EveConstGroupId.heavyFighter ||
  EveConstGroupId.structureHeavyFighter => SnapshotFighter_SquadronGroup.HEAVY,
  _ => SnapshotFighter_SquadronGroup.UNKNOWN,
};
