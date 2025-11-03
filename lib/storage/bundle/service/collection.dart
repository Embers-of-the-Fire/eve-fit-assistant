import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/data/proto/categories.pb.dart";
import "package:eve_fit_assistant/data/proto/collections.pb.dart";
import "package:eve_fit_assistant/data/proto/dogma_attributes.pb.dart";
import "package:eve_fit_assistant/data/proto/dogma_units.pb.dart";
import "package:eve_fit_assistant/data/proto/fit.pb.dart";
import "package:eve_fit_assistant/data/proto/groups.pb.dart";
import "package:eve_fit_assistant/data/proto/market_groups.pb.dart";
import "package:eve_fit_assistant/data/proto/meta_groups.pb.dart";
import "package:eve_fit_assistant/data/proto/type_materials.pb.dart";
import "package:eve_fit_assistant/data/proto/types.pb.dart" as pb_types;
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/storage/bundle/service/localization.dart";
import "package:eve_fit_assistant/storage/bundle/service/paths.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "collection.freezed.dart";
part "collection.g.dart";

@freezed
abstract class BundleCollectionStatus with _$BundleCollectionStatus {
  const factory BundleCollectionStatus.notInitialized() = _BundleCollectionStatusNotInitialized;
  const factory BundleCollectionStatus.loading() = _BundleCollectionStatusLoading;
  const factory BundleCollectionStatus.loaded(BundleCollectionProxy collection) =
      _BundleCollectionStatusLoaded;

  const BundleCollectionStatus._();

  BundleCollectionProxy? get collection => when(
    notInitialized: () {
      error("BundleCollection is not initialized", stackTrace: StackTrace.current);
      return null;
    },
    loading: () {
      error("BundleCollection is loading", stackTrace: StackTrace.current);
      return null;
    },
    loaded: (collection) => collection,
  );
}

class BundleCollectionProxy {
  const BundleCollectionProxy(this._collection);

  final Collection _collection;

  pb_types.Type? getType(int typeId) => _collection.types[typeId];
  Iterable<pb_types.Type> get allTypes => _collection.types.values;
  TypeMaterial? getTypeMaterial(int typeId) => _collection.typeMaterials[typeId];
  Iterable<TypeMaterial> get allTypeMaterials => _collection.typeMaterials.values;
  Category? getCategory(int categoryId) => _collection.categories[categoryId];
  Iterable<Category> get allCategories => _collection.categories.values;
  Group? getGroup(int groupId) => _collection.groups[groupId];
  Iterable<Group> get allGroups => _collection.groups.values;
  MarketGroup? getMarketGroup(int marketGroupId) => _collection.marketGroups[marketGroupId];
  Iterable<MarketGroup> get allMarketGroups => _collection.marketGroups.values;
  MetaGroup? getMetaGroup(int metaGroupId) => _collection.metaGroups[metaGroupId];
  Iterable<MetaGroup> get allMetaGroups => _collection.metaGroups.values;
  DogmaUnit? getDogmaUnit(int dogmaUnitId) => _collection.dogmaUnits[dogmaUnitId];
  Iterable<DogmaUnit> get allDogmaUnits => _collection.dogmaUnits.values;
  DogmaAttribute? getDogmaAttribute(int dogmaAttributeId) =>
      _collection.dogmaAttributes[dogmaAttributeId];
  Iterable<DogmaAttribute> get allDogmaAttributes => _collection.dogmaAttributes.values;
  Ship? getShip(int typeId) => _collection.ships[typeId];
  Iterable<Ship> get allShips => _collection.ships.values;
  Subsystem? getSubsystem(int typeId) => _collection.subsystems[typeId];
  Iterable<Subsystem> get allSubsystems => _collection.subsystems.values;
}

@riverpodSingleton
BundleCollectionProxy? bundleCollection(Ref ref) =>
    ref.watch(bundleCollectionServiceProvider.select((v) => v.collection));

@riverpod
pb_types.Type? bundleCollectionGetType(Ref ref, int typeId) =>
    ref.watch(bundleCollectionProvider.select((p) => p?.getType(typeId)));

@riverpod
Iterable<pb_types.Type> bundleCollectionGetAllTypes(Ref ref) =>
    ref.watch(bundleCollectionProvider.select((p) => p?.allTypes ?? const IList.empty()));

@riverpod
Iterable<TypeMaterial> bundleCollectionGetAllTypeMaterials(Ref ref) =>
    ref.watch(bundleCollectionProvider.select((p) => p?.allTypeMaterials ?? const IList.empty()));

@riverpod
Iterable<Category> bundleCollectionGetAllCategories(Ref ref) =>
    ref.watch(bundleCollectionProvider.select((p) => p?.allCategories ?? const IList.empty()));

@riverpod
Iterable<Group> bundleCollectionGetAllGroups(Ref ref) =>
    ref.watch(bundleCollectionProvider.select((p) => p?.allGroups ?? const IList.empty()));

@riverpod
Iterable<MarketGroup> bundleCollectionGetAllMarketGroups(Ref ref) =>
    ref.watch(bundleCollectionProvider.select((p) => p?.allMarketGroups ?? const IList.empty()));

@riverpod
Iterable<MetaGroup> bundleCollectionGetAllMetaGroups(Ref ref) =>
    ref.watch(bundleCollectionProvider.select((p) => p?.allMetaGroups ?? const IList.empty()));

@riverpod
Iterable<DogmaUnit> bundleCollectionGetAllDogmaUnits(Ref ref) =>
    ref.watch(bundleCollectionProvider.select((p) => p?.allDogmaUnits ?? const IList.empty()));

@riverpod
Iterable<DogmaAttribute> bundleCollectionGetAllDogmaAttributes(Ref ref) =>
    ref.watch(bundleCollectionProvider.select((p) => p?.allDogmaAttributes ?? const IList.empty()));

@riverpod
Iterable<Ship> bundleCollectionGetAllShips(Ref ref) =>
    ref.watch(bundleCollectionProvider.select((p) => p?.allShips ?? const IList.empty()));

@riverpod
Iterable<Subsystem> bundleCollectionGetAllSubsystems(Ref ref) =>
    ref.watch(bundleCollectionProvider.select((p) => p?.allSubsystems ?? const IList.empty()));

@riverpod
TypeMaterial? bundleCollectionGetTypeMaterial(Ref ref, int typeId) =>
    ref.watch(bundleCollectionProvider.select((p) => p?.getTypeMaterial(typeId)));

@riverpod
Category? bundleCollectionGetCategory(Ref ref, int categoryId) =>
    ref.watch(bundleCollectionProvider.select((p) => p?.getCategory(categoryId)));

@riverpod
Group? bundleCollectionGetGroup(Ref ref, int groupId) =>
    ref.watch(bundleCollectionProvider.select((p) => p?.getGroup(groupId)));

@riverpod
MarketGroup? bundleCollectionGetMarketGroup(Ref ref, int marketGroupId) =>
    ref.watch(bundleCollectionProvider.select((p) => p?.getMarketGroup(marketGroupId)));

@riverpod
MetaGroup? bundleCollectionGetMetaGroup(Ref ref, int metaGroupId) =>
    ref.watch(bundleCollectionProvider.select((p) => p?.getMetaGroup(metaGroupId)));

@riverpod
DogmaUnit? bundleCollectionGetDogmaUnit(Ref ref, int dogmaUnitId) =>
    ref.watch(bundleCollectionProvider.select((p) => p?.getDogmaUnit(dogmaUnitId)));

@riverpod
DogmaAttribute? bundleCollectionGetDogmaAttribute(Ref ref, int dogmaAttributeId) =>
    ref.watch(bundleCollectionProvider.select((p) => p?.getDogmaAttribute(dogmaAttributeId)));

@riverpod
Ship? bundleCollectionGetShip(Ref ref, int typeId) =>
    ref.watch(bundleCollectionProvider.select((p) => p?.getShip(typeId)));

@riverpod
Subsystem? bundleCollectionGetSubsystem(Ref ref, int typeId) =>
    ref.watch(bundleCollectionProvider.select((p) => p?.getSubsystem(typeId)));

@riverpodSingleton
class BundleCollectionService extends _$BundleCollectionService {
  static bool _isLoading = false;

  @override
  BundleCollectionStatus build() {
    ref.listen(bundleServiceProvider, (prev, next) async {
      if (!next.isLoaded) return;
      ref.read(bundleLocalizationProvider);
      await _loadCollection();
    });
    return const BundleCollectionStatus.notInitialized();
  }

  Future<void> _loadCollection() async {
    // Load guard to prevent multiple simultaneous loads
    if (_isLoading) return;
    _isLoading = true;
    state = const BundleCollectionStatus.loading();
    final filePath = ref.read(bundlePathsProvider)?.getCollectionPath() ?? "";
    final file = File(filePath);
    if (!file.existsSync()) {
      _isLoading = false;
      return;
    }
    final bytes = await file.readAsBytes();
    final collection = Collection.fromBuffer(bytes);
    _isLoading = false;
    state = BundleCollectionStatus.loaded(BundleCollectionProxy(collection));
  }
}
