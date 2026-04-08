import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/constant/eve.dart";
import "package:eve_fit_assistant/data/proto/fit.pb.dart";
import "package:eve_fit_assistant/native/api/storage.dart" as native;
import "package:eve_fit_assistant/storage/character/schema.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fpdart/fpdart.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:path/path.dart" as p;

part "schema.freezed.dart";
part "schema.g.dart";

@freezed
abstract class FitStorage with _$FitStorage {
  const factory FitStorage({
    required FitMetadata metadata,
    required FitStorageBody body,
    required FitDynamicRegistry dynamicRegistry,
  }) = _FitStorage;
  factory FitStorage.empty(FitMetadata metadata, Ship ship) => FitStorage(
    metadata: metadata,
    body: FitStorageBody(
      shipTypeId: ship.typeId,
      characterId: predefinedMaxCharacterId,
      damageProfile: const FitDamageProfile(
        em: 0.25,
        explosive: 0.25,
        kinetic: 0.25,
        thermal: 0.25,
      ),
      slots: FitStorageSlots.empty(ship),
      drones: IList<FitDroneItem>(),
      fighters: IList<FitFighterItem>(),
      implants: IList<FitImplantItem>(),
      boosters: IList<FitBoosterItem>(),
    ),
    dynamicRegistry: FitDynamicRegistry(dynamicItems: IMap<int, FitDynamicItem>()),
  );

  const FitStorage._();

  factory FitStorage.fromJson(Map<String, dynamic> json) => _$FitStorageFromJson(json);

  String get fitStoragePath => p.join(PathProvider.fittingsPath, "${metadata.fitId}.json");

  static String fitStoragePathForId(String fitId) =>
      p.join(PathProvider.fittingsPath, "$fitId.json");
}

@freezed
abstract class FitStorageBody with _$FitStorageBody {
  const factory FitStorageBody({
    required int shipTypeId,
    @JsonKey(readValue: _readCharacterId) required String characterId,
    required FitDamageProfile damageProfile,
    required FitStorageSlots slots,
    required IList<FitDroneItem> drones,
    required IList<FitFighterItem> fighters,
    required IList<FitImplantItem> implants,
    required IList<FitBoosterItem> boosters,
  }) = _FitStorageBody;

  factory FitStorageBody.fromJson(Map<String, dynamic> json) => _$FitStorageBodyFromJson(json);
}

Object? _readCharacterId(Map<dynamic, dynamic> json, String key) =>
    json[key] ??
    switch (json["skillProfile"]) {
      "all0" => predefinedZeroCharacterId,
      _ => predefinedMaxCharacterId,
    };

/// The length of any slot is fixed (or partially fixed, since we have subsystems) for a given ship.
/// So we can use a list to represent the slots, and use `None` to represent empty slots.
///
/// However, that means we must get a ship definition (and subsystem definitions)
/// to construct a empty fit for a given ship.
/// This shall be done within a Ref context, so the initialization must be called by a manager.
@freezed
abstract class FitStorageSlots with _$FitStorageSlots {
  const factory FitStorageSlots({
    required IList<Option<FitModuleItem>> high,
    required IList<Option<FitModuleItem>> medium,
    required IList<Option<FitModuleItem>> low,
    required IList<Option<FitModuleItem>> rig,
    required IList<Option<FitModuleItem>> subsystem,
    required IList<Option<FitModuleItem>> service,
    required Option<int> tacticalMode,
  }) = _FitStorageSlots;

  const FitStorageSlots._();

  factory FitStorageSlots.fromJson(Map<String, dynamic> json) => _$FitStorageSlotsFromJson(json);

  factory FitStorageSlots.empty(Ship ship) => FitStorageSlots(
    high: IList(const Option<FitModuleItem>.none().repeat(ship.highSlots)),
    medium: IList(const Option<FitModuleItem>.none().repeat(ship.mediumSlots)),
    low: IList(const Option<FitModuleItem>.none().repeat(ship.lowSlots)),
    rig: IList(const Option<FitModuleItem>.none().repeat(ship.rigSlots)),
    subsystem: IList(const Option<FitModuleItem>.none().repeat(EveConstGeneric.subsystemSize)),
    service: IList(const Option<FitModuleItem>.none().repeat(ship.serviceSlots)),
    tacticalMode: ship.tacticalModes.isEmpty
        ? const Option<int>.none()
        : ship.tacticalModes.firstOption.map((t) => t.typeId),
  );
}

@freezed
abstract class FitDamageProfile with _$FitDamageProfile {
  const factory FitDamageProfile({
    required double em,
    required double explosive,
    required double kinetic,
    required double thermal,
  }) = _FitDamageProfile;

  factory FitDamageProfile.fromJson(Map<String, dynamic> json) => _$FitDamageProfileFromJson(json);
}

@freezed
abstract class FitStorageItemId with _$FitStorageItemId {
  const factory FitStorageItemId.item({required int id}) = FitStorageItemIdItem;
  const factory FitStorageItemId.dynamic({required int dynamicId}) = FitStorageItemIdDynamic;

  const FitStorageItemId._();

  factory FitStorageItemId.fromJson(Map<String, dynamic> json) => _$FitStorageItemIdFromJson(json);

  int get asId => when(item: (id) => id, dynamic: (dynamicId) => dynamicId);

  int? get dynamicIdOrNull => when(item: (_) => null, dynamic: (dynamicId) => dynamicId);
}

@JsonEnum()
enum FitItemState { passive, online, active, overload }

@freezed
abstract class FitModuleItem with _$FitModuleItem {
  const factory FitModuleItem({
    required FitStorageItemId itemId,
    required FitItemState state,
    required Option<FitChargeItem> charge,
  }) = _FitModuleItem;

  factory FitModuleItem.fromJson(Map<String, dynamic> json) => _$FitModuleItemFromJson(json);
}

@freezed
abstract class FitChargeItem with _$FitChargeItem {
  const factory FitChargeItem({required int typeId}) = _FitChargeItem;

  factory FitChargeItem.fromJson(Map<String, dynamic> json) => _$FitChargeItemFromJson(json);
}

@freezed
abstract class FitDroneItem with _$FitDroneItem {
  const factory FitDroneItem({
    required FitStorageItemId itemId,
    required FitItemState state,
    required int quantity,
  }) = _FitDroneItem;

  factory FitDroneItem.fromJson(Map<String, dynamic> json) => _$FitDroneItemFromJson(json);
}

@freezed
abstract class FitFighterItem with _$FitFighterItem {
  const factory FitFighterItem({
    required FitStorageItemId itemId,
    required int groupId,
    @JsonKey(defaultValue: 1) required int quantity,
    required int fighterAbility,
  }) = _FitFighterItem;

  factory FitFighterItem.fromJson(Map<String, dynamic> json) => _$FitFighterItemFromJson(json);
}

@freezed
abstract class FitImplantItem with _$FitImplantItem {
  const factory FitImplantItem({required FitStorageItemId itemId, required FitItemState state}) =
      _FitImplantItem;

  factory FitImplantItem.fromJson(Map<String, dynamic> json) => _$FitImplantItemFromJson(json);
}

@freezed
abstract class FitBoosterItem with _$FitBoosterItem {
  const factory FitBoosterItem({
    required FitStorageItemId itemId,
    required int index,
    required FitItemState state,
  }) = _FitBoosterItem;

  factory FitBoosterItem.fromJson(Map<String, dynamic> json) => _$FitBoosterItemFromJson(json);
}

@freezed
abstract class FitDynamicItem with _$FitDynamicItem {
  const factory FitDynamicItem({
    required int dynamicItemId,
    required int originTypeId,
    required int typeId,
    required int modifierTypeId,
    required IMap<int, double> dynamicAttributes,
  }) = _FitDynamicItem;

  factory FitDynamicItem.fromJson(Map<String, dynamic> json) => _$FitDynamicItemFromJson(json);
}

@freezed
abstract class FitDynamicRegistry with _$FitDynamicRegistry {
  const factory FitDynamicRegistry({required IMap<int, FitDynamicItem> dynamicItems}) =
      _FitDynamicRegistry;

  factory FitDynamicRegistry.fromJson(Map<String, dynamic> json) =>
      _$FitDynamicRegistryFromJson(json);
}

Set<int> collectReferencedDynamicItemIds(FitStorage fit) {
  final referencedIds = <int>{};

  void add(FitStorageItemId itemId) {
    final dynamicId = itemId.dynamicIdOrNull;
    if (dynamicId != null) {
      referencedIds.add(dynamicId);
    }
  }

  for (final slotList in [
    fit.body.slots.high,
    fit.body.slots.medium,
    fit.body.slots.low,
    fit.body.slots.rig,
    fit.body.slots.subsystem,
    fit.body.slots.service,
  ]) {
    for (final slot in slotList.filterNone()) {
      add(slot.itemId);
    }
  }

  for (final drone in fit.body.drones) {
    add(drone.itemId);
  }
  for (final fighter in fit.body.fighters) {
    add(fighter.itemId);
  }
  for (final implant in fit.body.implants) {
    add(implant.itemId);
  }
  for (final booster in fit.body.boosters) {
    add(booster.itemId);
  }

  return referencedIds;
}

int allocateDynamicItemId(FitStorage fit) {
  final referencedIds = collectReferencedDynamicItemIds(fit);
  var nextId = 0;
  while (referencedIds.contains(nextId)) {
    nextId += 1;
  }
  return nextId;
}

FitStorage pruneDynamicRegistry(FitStorage fit) {
  final referencedIds = collectReferencedDynamicItemIds(fit);
  final prunedDynamicItems = fit.dynamicRegistry.dynamicItems.removeWhere(
    (dynamicId, _) => !referencedIds.contains(dynamicId),
  );

  if (identical(prunedDynamicItems, fit.dynamicRegistry.dynamicItems) ||
      prunedDynamicItems == fit.dynamicRegistry.dynamicItems) {
    return fit;
  }

  return fit.copyWith(
    dynamicRegistry: fit.dynamicRegistry.copyWith(dynamicItems: prunedDynamicItems),
  );
}

bool _hasValidDynamicReference(
  FitStorage fitStorage,
  FitStorageItemId itemId, {
  required String context,
}) => itemId.when(
  item: (_) => true,
  dynamic: (dynamicId) {
    if (fitStorage.dynamicRegistry.dynamicItems.containsKey(dynamicId)) {
      return true;
    }
    warning("Missing dynamic item $dynamicId while converting fit: $context");
    return false;
  },
);

int? _resolveNativeTypeId(
  FitStorage fitStorage,
  FitStorageItemId itemId, {
  required String context,
}) => itemId.when(
  item: (id) => id,
  dynamic: (dynamicId) {
    final dynamicItem = fitStorage.dynamicRegistry.dynamicItems[dynamicId];
    if (dynamicItem == null) {
      warning("Missing dynamic item $dynamicId while converting fit: $context");
      return null;
    }
    return dynamicItem.typeId;
  },
);

native.FitStorage convertToNative(FitStorage fitStorage, {required Map<int, int> characterSkills}) {
  final validDynamicIds = collectReferencedDynamicItemIds(
    fitStorage,
  ).intersection(fitStorage.dynamicRegistry.dynamicItems.keys.toSet());

  final modules = <native.Module>[];

  for (final slotGroup in [
    (fitStorage.body.slots.high, native.SlotType.high, "high"),
    (fitStorage.body.slots.medium, native.SlotType.medium, "medium"),
    (fitStorage.body.slots.low, native.SlotType.low, "low"),
    (fitStorage.body.slots.rig, native.SlotType.rig, "rig"),
    (
      fitStorage.body.slots.subsystem.map(
        (slotOpt) => slotOpt.map((slot) => slot.copyWith(state: FitItemState.online)),
      ),
      native.SlotType.subSystem,
      "subsystem",
    ),
    (fitStorage.body.slots.service, native.SlotType.service, "service"),
  ]) {
    for (final (index, slot) in slotGroup.$1.mapWithIndex((slot, index) => (index, slot))) {
      slot.match(() {}, (slot) {
        if (!_hasValidDynamicReference(
          fitStorage,
          slot.itemId,
          context: "${slotGroup.$3} slot $index in fit ${fitStorage.metadata.fitId}",
        )) {
          return;
        }
        modules.add(
          native.Module(
            itemId: slot.itemId.when(item: native.ItemID.item, dynamic: native.ItemID.dynamic_),
            state: switch (slot.state) {
              FitItemState.passive => native.State.passive,
              FitItemState.online => native.State.online,
              FitItemState.active => native.State.active,
              FitItemState.overload => native.State.overload,
            },
            charge: slot.charge.map((charge) => native.Charge(typeId: charge.typeId)).nullable,
            slot: native.Slot(slotType: slotGroup.$2, index: index),
          ),
        );
      });
    }
  }

  final drones = <native.Drone>[];
  for (final (index, drone) in fitStorage.body.drones.mapWithIndex(
    (drone, index) => (index, drone),
  )) {
    final typeId = _resolveNativeTypeId(
      fitStorage,
      drone.itemId,
      context: "drone $index in fit ${fitStorage.metadata.fitId}",
    );
    if (typeId == null) continue;
    drones.addAll(
      List.generate(
        drone.quantity,
        (_) => native.Drone(
          typeId: typeId,
          groupId: index,
          state: switch (drone.state) {
            FitItemState.passive => native.State.passive,
            FitItemState.online => native.State.online,
            FitItemState.active => native.State.active,
            FitItemState.overload => native.State.overload,
          },
        ),
      ),
    );
  }

  final fighters = <native.Fighter>[];
  for (final (index, fighter) in fitStorage.body.fighters.mapWithIndex(
    (fighter, index) => (index, fighter),
  )) {
    final typeId = _resolveNativeTypeId(
      fitStorage,
      fighter.itemId,
      context: "fighter $index in fit ${fitStorage.metadata.fitId}",
    );
    if (typeId == null) continue;
    fighters.addAll(
      List.generate(
        fighter.quantity,
        (_) => native.Fighter(
          typeId: typeId,
          groupId: fighter.groupId,
          ability: fighter.fighterAbility,
        ),
      ),
    );
  }

  final implants = <native.Implant>[];
  for (final (index, implant)
      in fitStorage.body.implants
          .where((implant) => implant.state != FitItemState.passive)
          .mapWithIndex((implant, index) => (index, implant))) {
    final typeId = _resolveNativeTypeId(
      fitStorage,
      implant.itemId,
      context: "implant $index in fit ${fitStorage.metadata.fitId}",
    );
    if (typeId == null) continue;
    implants.add(native.Implant(typeId: typeId, index: index));
  }

  final boosters = <native.Booster>[];
  for (final booster in fitStorage.body.boosters.where(
    (booster) => booster.state != FitItemState.passive,
  )) {
    final typeId = _resolveNativeTypeId(
      fitStorage,
      booster.itemId,
      context: "booster slot ${booster.index} in fit ${fitStorage.metadata.fitId}",
    );
    if (typeId == null) continue;
    boosters.add(native.Booster(typeId: typeId, index: booster.index));
  }

  return native.FitStorage(
    fit: native.Fit(
      shipTypeId: fitStorage.body.shipTypeId,
      damageProfile: native.DamageProfile(
        em: fitStorage.body.damageProfile.em,
        explosive: fitStorage.body.damageProfile.explosive,
        kinetic: fitStorage.body.damageProfile.kinetic,
        thermal: fitStorage.body.damageProfile.thermal,
      ),
      modules: [
        ...modules,
        if (fitStorage.body.slots.tacticalMode case Some(:final value))
          native.Module(
            itemId: native.ItemID.item(value),
            state: native.State.online,
            slot: const native.Slot(slotType: native.SlotType.tacticalMode, index: 0),
          ),
      ],
      drones: drones,
      fighters: fighters,
      implants: implants,
      boosters: boosters,
    ),
    skills: characterSkills,
    dynamicItems: Map<int, native.DynamicItem>.fromEntries(
      fitStorage.dynamicRegistry.dynamicItems.entries
          .where((entry) => validDynamicIds.contains(entry.key))
          .map(
            (entry) => MapEntry(
              entry.key,
              native.DynamicItem(
                baseType: entry.value.originTypeId,
                dynamicAttributes: Map<int, double>.from(entry.value.dynamicAttributes.unlock),
              ),
            ),
          ),
    ),
  );
}
