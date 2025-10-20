import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/data/proto/fit.pb.dart";
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
      damageProfile: const FitDamageProfile(em: 0, explosive: 0, kinetic: 0, thermal: 0),
      slots: FitStorageSlots.empty(ship),
      drones: IList<FitDroneItem>(),
      fighters: IList<FitFighterItem>(),
      implants: IList<FitImplantItem>(),
      boosters: IList<FitBoosterItem>(),
    ),
    dynamicRegistry: FitDynamicRegistry(dynamicItems: IMap<int, IMap<int, double>>()),
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
    required FitDamageProfile damageProfile,
    required FitStorageSlots slots,
    required IList<FitDroneItem> drones,
    required IList<FitFighterItem> fighters,
    required IList<FitImplantItem> implants,
    required IList<FitBoosterItem> boosters,
  }) = _FitStorageBody;

  factory FitStorageBody.fromJson(Map<String, dynamic> json) => _$FitStorageBodyFromJson(json);
}

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
    required Option<FitModuleItem> tacticalMode,
  }) = _FitStorageSlots;

  const FitStorageSlots._();

  factory FitStorageSlots.fromJson(Map<String, dynamic> json) => _$FitStorageSlotsFromJson(json);

  factory FitStorageSlots.empty(Ship ship) => FitStorageSlots(
    high: IList(const Option<FitModuleItem>.none().repeat(ship.highSlots)),
    medium: IList(const Option<FitModuleItem>.none().repeat(ship.mediumSlots)),
    low: IList(const Option<FitModuleItem>.none().repeat(ship.lowSlots)),
    rig: IList(const Option<FitModuleItem>.none().repeat(ship.rigSlots)),
    subsystem: IList(const Option<FitModuleItem>.none().repeat(ship.subsystemSlots)),
    service: IList(const Option<FitModuleItem>.none().repeat(ship.serviceSlots)),
    tacticalMode: const Option.none(),
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
  const factory FitStorageItemId.item({required int id}) = _FitStorageItemIdItem;
  const factory FitStorageItemId.dynamic({required int dynamicId}) = _FitStorageItemIdDynamic;

  factory FitStorageItemId.fromJson(Map<String, dynamic> json) => _$FitStorageItemIdFromJson(json);
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
  const factory FitChargeItem({required FitStorageItemId itemId}) = _FitChargeItem;

  factory FitChargeItem.fromJson(Map<String, dynamic> json) => _$FitChargeItemFromJson(json);
}

@freezed
abstract class FitDroneItem with _$FitDroneItem {
  const factory FitDroneItem({
    required FitStorageItemId itemId,
    required int groupId,
    required FitItemState state,
  }) = _FitDroneItem;

  factory FitDroneItem.fromJson(Map<String, dynamic> json) => _$FitDroneItemFromJson(json);
}

@freezed
abstract class FitFighterItem with _$FitFighterItem {
  const factory FitFighterItem({
    required FitStorageItemId itemId,
    required int groupId,
    required int fighterAbility,
  }) = _FitFighterItem;

  factory FitFighterItem.fromJson(Map<String, dynamic> json) => _$FitFighterItemFromJson(json);
}

@freezed
abstract class FitImplantItem with _$FitImplantItem {
  const factory FitImplantItem({required FitStorageItemId itemId}) = _FitImplantItem;

  factory FitImplantItem.fromJson(Map<String, dynamic> json) => _$FitImplantItemFromJson(json);
}

@freezed
abstract class FitBoosterItem with _$FitBoosterItem {
  const factory FitBoosterItem({required FitStorageItemId itemId, required int index}) =
      _FitBoosterItem;

  factory FitBoosterItem.fromJson(Map<String, dynamic> json) => _$FitBoosterItemFromJson(json);
}

@freezed
abstract class FitDynamicRegistry with _$FitDynamicRegistry {
  const factory FitDynamicRegistry({required IMap<int, IMap<int, double>> dynamicItems}) =
      _FitDynamicRegistry;

  factory FitDynamicRegistry.fromJson(Map<String, dynamic> json) =>
      _$FitDynamicRegistryFromJson(json);
}
