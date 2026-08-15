import "dart:typed_data";

import "package:efa_compat/io.dart";
import "package:efa_proto/categories.pb.dart" as pb_categories;
import "package:efa_proto/collections.pb.dart";
import "package:efa_proto/dogma_attributes.pb.dart" as pb_attrs;
import "package:efa_proto/dogma_units.pb.dart" as pb_units;
import "package:efa_proto/dynamic.pb.dart" as pb_dynamic;
import "package:efa_proto/fit.pb.dart";
import "package:efa_proto/groups.pb.dart" as pb_groups;
import "package:efa_proto/market_groups.pb.dart" as pb_market;
import "package:efa_proto/meta_groups.pb.dart" as pb_meta;
import "package:efa_proto/type_materials.pb.dart" as pb_materials;
import "package:efa_proto/types.pb.dart" as pb_types;
import "package:eve_fit_assistant/constant/eve.dart";
import "package:eve_fit_assistant/storage/repo/collection_chunked_decode.dart";
import "package:eve_fit_assistant/storage/repo/data_readiness.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/foundation.dart" show visibleForTesting;
import "package:riverpod_annotation/riverpod_annotation.dart";

part "collection.g.dart";

// ignore_for_file: prefer_initializing_formals

/// Pre-loaded type data from the active checkout's resource snapshot.
///
/// Built on checkout activation via [DataReadinessNotifier] which decodes
/// off the main isolate. Returns `null` while loading or when no checkout
/// is active. Consumers should show skeletons when this is null and the
/// readiness state is [DataReadinessLoading].
@riverpodSingleton
RepoCollectionService? repoCollection(Ref ref) {
  ref.watch(dataReadinessProvider);
  return ref.read(dataReadinessProvider.notifier).decodedCollection;
}

/// Pre-loaded type data proxy backed by the content-addressed blob store.
///
/// Structural type-data only, decoded from a single Collection.toBuffer
/// file referenced by the repo's ResourceIndex. Localized names resolve
/// via `LocalizationDbService`.
class RepoCollectionService {
  const RepoCollectionService._({
    required Collection collection,
    required IMap<int, Ship> ships,
    required IMap<int, pb_types.Type> types,
    required IList<int> skillTypeIds,
    required IMap<String, IMap<int, int>> skillProfiles,
    required IMap<int, pb_categories.Category> categories,
    required IMap<int, pb_groups.Group> groups,
    required IMap<int, pb_market.MarketGroup> marketGroups,
    required IMap<int, pb_meta.MetaGroup> metaGroups,
    required IMap<int, pb_units.DogmaUnit> dogmaUnits,
    required IMap<int, pb_attrs.DogmaAttribute> dogmaAttributes,
    required IMap<int, Subsystem> subsystems,
    required IMap<int, pb_materials.TypeMaterial> typeMaterials,
    required IMap<int, pb_dynamic.DynamicMutator> dynamicMutators,
    required IMap<int, pb_dynamic.DynamicTypeOptions> dynamicTypeOptions,
    required IMap<int, ImplantSet> implantSets,
    required IMap<int, int> implantTypeToSet,
  }) : _collection = collection,
       _ships = ships,
       _types = types,
       _skillTypeIds = skillTypeIds,
       _skillProfiles = skillProfiles,
       _categories = categories,
       _groups = groups,
       _marketGroups = marketGroups,
       _metaGroups = metaGroups,
       _dogmaUnits = dogmaUnits,
       _dogmaAttributes = dogmaAttributes,
       _subsystems = subsystems,
       _typeMaterials = typeMaterials,
       _dynamicMutators = dynamicMutators,
       _dynamicTypeOptions = dynamicTypeOptions,
       _implantSets = implantSets,
       _implantTypeToSet = implantTypeToSet;

  /// Builds a [RepoCollectionService] from a [Collection] protobuf for testing.
  ///
  /// Skips reading from the blob store and ResourceIndex.
  @visibleForTesting
  factory RepoCollectionService.forTest({required Collection collection}) {
    final ships = IMap.fromEntries(collection.ships.entries.map((e) => MapEntry(e.key, e.value)));
    final types = IMap.fromEntries(collection.types.entries.map((e) => MapEntry(e.key, e.value)));

    final skillGroupIds = collection.groups.values
        .where((group) => group.categoryId == EveConstCategoryId.skill)
        .map((group) => group.groupId)
        .toSet();

    final skillTypeIds = collection.types.values
        .where((type) => skillGroupIds.contains(type.groupId))
        .map((type) => type.typeId)
        .toIList();

    return RepoCollectionService._(
      collection: collection,
      ships: ships,
      types: types,
      skillTypeIds: skillTypeIds,
      skillProfiles: const IMap.empty(),
      categories: const IMap.empty(),
      groups: const IMap.empty(),
      marketGroups: const IMap.empty(),
      metaGroups: const IMap.empty(),
      dogmaUnits: const IMap.empty(),
      dogmaAttributes: const IMap.empty(),
      subsystems: const IMap.empty(),
      typeMaterials: const IMap.empty(),
      dynamicMutators: const IMap.empty(),
      dynamicTypeOptions: const IMap.empty(),
      implantSets: const IMap.empty(),
      implantTypeToSet: const IMap.empty(),
    );
  }

  /// Builds a [RepoCollectionService] by reading the collection protobuf file
  /// directly from a filesystem path. Suitable for use inside an isolate since
  /// it performs no provider lookups or shared-state access.
  ///
  /// Native-only: on web, blobs live in OPFS and have no filesystem path —
  /// use `decodeFromBytes` there.
  factory RepoCollectionService.decodeFromPaths({required String collectionPath}) =>
      _decode(Uint8List.fromList(File(collectionPath).readAsBytesSync()));

  /// Builds a [RepoCollectionService] from in-memory collection protobuf bytes.
  ///
  /// The web decode path: blobs are read from OPFS through the blob store
  /// (async) and decoded here. Suitable for use inside an isolate since it
  /// performs no provider lookups or shared-state access.
  factory RepoCollectionService.decodeFromBytes({required Uint8List collectionBytes}) =>
      _decode(collectionBytes);

  static RepoCollectionService _decode(Uint8List collectionRaw) =>
      _assemble(Collection.fromBuffer(collectionRaw));

  /// Builds a [RepoCollectionService] from in-memory protobuf bytes without
  /// ever blocking the event loop for long.
  ///
  /// The web decode path: web has no isolates, so the synchronous
  /// [RepoCollectionService.decodeFromBytes] would freeze the UI for the whole
  /// decode (hundreds of milliseconds for a full bundle). This variant decodes
  /// entry by entry, yielding to the event loop between chunks, at the cost of
  /// a slightly longer total decode time.
  static Future<RepoCollectionService> decodeFromBytesChunked({
    required Uint8List collectionBytes,
    bool Function()? isCancelled,
  }) async {
    final options = ChunkedDecodeOptions(isCancelled: isCancelled);
    final collection = await decodeCollectionChunked(collectionBytes, options);
    return _assembleAsync(collection, options);
  }

  /// Builds the index maps from an already-decoded collection message.
  // ignore: prefer_constructors_over_static_methods
  static RepoCollectionService _assemble(Collection collection) {
    final ships = IMap.fromEntries(collection.ships.entries.map((e) => MapEntry(e.key, e.value)));
    final types = IMap.fromEntries(collection.types.entries.map((e) => MapEntry(e.key, e.value)));
    final categories = IMap.fromEntries(
      collection.categories.entries.map((e) => MapEntry(e.key, e.value)),
    );
    final groups = IMap.fromEntries(collection.groups.entries.map((e) => MapEntry(e.key, e.value)));
    final marketGroups = IMap.fromEntries(
      collection.marketGroups.entries.map((e) => MapEntry(e.key, e.value)),
    );
    final metaGroups = IMap.fromEntries(
      collection.metaGroups.entries.map((e) => MapEntry(e.key, e.value)),
    );
    final dogmaUnits = IMap.fromEntries(
      collection.dogmaUnits.entries.map((e) => MapEntry(e.key, e.value)),
    );
    final dogmaAttributes = IMap.fromEntries(
      collection.dogmaAttributes.entries.map((e) => MapEntry(e.key, e.value)),
    );
    final subsystems = IMap.fromEntries(
      collection.subsystems.entries.map((e) => MapEntry(e.key, e.value)),
    );
    final typeMaterials = IMap.fromEntries(
      collection.typeMaterials.entries.map((e) => MapEntry(e.key, e.value)),
    );
    final dynamicMutators = IMap.fromEntries(
      collection.dynamicMutators.entries.map((e) => MapEntry(e.key, e.value)),
    );
    final dynamicTypeOptions = IMap.fromEntries(
      collection.dynamicTypeOptions.entries.map((e) => MapEntry(e.key, e.value)),
    );
    final implantSets = IMap.fromEntries(
      collection.implantSets.entries.map((e) => MapEntry(e.key, e.value)),
    );
    final implantTypeToSet = IMap.fromEntries([
      for (final set in implantSets.values)
        for (final typeId in set.memberTypeIds) MapEntry(typeId, set.setId),
    ]);

    final skillGroupIds = collection.groups.values
        .where((group) => group.categoryId == EveConstCategoryId.skill)
        .map((group) => group.groupId)
        .toSet();

    final skillTypeIds = collection.types.values
        .where((type) => skillGroupIds.contains(type.groupId))
        .map((type) => type.typeId)
        .toIList();

    final skillProfiles = <String, IMap<int, int>>{};
    for (final entry in collection.skillProfiles.entries) {
      skillProfiles[entry.key] = IMap.fromEntries(
        entry.value.skills.entries.map((e) => MapEntry(e.key, e.value)),
      );
    }

    return RepoCollectionService._(
      collection: collection,
      ships: ships,
      types: types,
      skillTypeIds: skillTypeIds,
      skillProfiles: skillProfiles.toIMap(),
      categories: categories,
      groups: groups,
      marketGroups: marketGroups,
      metaGroups: metaGroups,
      dogmaUnits: dogmaUnits,
      dogmaAttributes: dogmaAttributes,
      subsystems: subsystems,
      typeMaterials: typeMaterials,
      dynamicMutators: dynamicMutators,
      dynamicTypeOptions: dynamicTypeOptions,
      implantSets: implantSets,
      implantTypeToSet: implantTypeToSet,
    );
  }

  /// Chunked counterpart of [_assemble]: identical index construction, but
  /// yields to the event loop between the individual map builds so no single
  /// synchronous stretch exceeds the pacing budget by much.
  static Future<RepoCollectionService> _assembleAsync(
    Collection collection,
    ChunkedDecodeOptions options,
  ) async {
    final pacemaker = ChunkedPacemaker(options);

    final ships = IMap.fromEntries(collection.ships.entries.map((e) => MapEntry(e.key, e.value)));
    await pacemaker.tick();
    final types = IMap.fromEntries(collection.types.entries.map((e) => MapEntry(e.key, e.value)));
    await pacemaker.tick();
    final categories = IMap.fromEntries(
      collection.categories.entries.map((e) => MapEntry(e.key, e.value)),
    );
    await pacemaker.tick();
    final groups = IMap.fromEntries(collection.groups.entries.map((e) => MapEntry(e.key, e.value)));
    await pacemaker.tick();
    final marketGroups = IMap.fromEntries(
      collection.marketGroups.entries.map((e) => MapEntry(e.key, e.value)),
    );
    await pacemaker.tick();
    final metaGroups = IMap.fromEntries(
      collection.metaGroups.entries.map((e) => MapEntry(e.key, e.value)),
    );
    await pacemaker.tick();
    final dogmaUnits = IMap.fromEntries(
      collection.dogmaUnits.entries.map((e) => MapEntry(e.key, e.value)),
    );
    await pacemaker.tick();
    final dogmaAttributes = IMap.fromEntries(
      collection.dogmaAttributes.entries.map((e) => MapEntry(e.key, e.value)),
    );
    await pacemaker.tick();
    final subsystems = IMap.fromEntries(
      collection.subsystems.entries.map((e) => MapEntry(e.key, e.value)),
    );
    await pacemaker.tick();
    final typeMaterials = IMap.fromEntries(
      collection.typeMaterials.entries.map((e) => MapEntry(e.key, e.value)),
    );
    await pacemaker.tick();
    final dynamicMutators = IMap.fromEntries(
      collection.dynamicMutators.entries.map((e) => MapEntry(e.key, e.value)),
    );
    await pacemaker.tick();
    final dynamicTypeOptions = IMap.fromEntries(
      collection.dynamicTypeOptions.entries.map((e) => MapEntry(e.key, e.value)),
    );
    await pacemaker.tick();
    final implantSets = IMap.fromEntries(
      collection.implantSets.entries.map((e) => MapEntry(e.key, e.value)),
    );
    await pacemaker.tick();
    final implantTypeToSet = IMap.fromEntries([
      for (final set in implantSets.values)
        for (final typeId in set.memberTypeIds) MapEntry(typeId, set.setId),
    ]);
    await pacemaker.tick();

    final skillGroupIds = collection.groups.values
        .where((group) => group.categoryId == EveConstCategoryId.skill)
        .map((group) => group.groupId)
        .toSet();

    final skillTypeIds = collection.types.values
        .where((type) => skillGroupIds.contains(type.groupId))
        .map((type) => type.typeId)
        .toIList();
    await pacemaker.tick();

    final skillProfiles = <String, IMap<int, int>>{};
    for (final entry in collection.skillProfiles.entries) {
      skillProfiles[entry.key] = IMap.fromEntries(
        entry.value.skills.entries.map((e) => MapEntry(e.key, e.value)),
      );
    }
    await pacemaker.tick();

    return RepoCollectionService._(
      collection: collection,
      ships: ships,
      types: types,
      skillTypeIds: skillTypeIds,
      skillProfiles: skillProfiles.toIMap(),
      categories: categories,
      groups: groups,
      marketGroups: marketGroups,
      metaGroups: metaGroups,
      dogmaUnits: dogmaUnits,
      dogmaAttributes: dogmaAttributes,
      subsystems: subsystems,
      typeMaterials: typeMaterials,
      dynamicMutators: dynamicMutators,
      dynamicTypeOptions: dynamicTypeOptions,
      implantSets: implantSets,
      implantTypeToSet: implantTypeToSet,
    );
  }

  // ── Internal data ──
  final Collection _collection;

  // ── Pre-built indexes for hot-path lookups ──
  final IMap<int, Ship> _ships;
  final IMap<int, pb_types.Type> _types;
  final IList<int> _skillTypeIds;
  final IMap<String, IMap<int, int>> _skillProfiles;
  final IMap<int, pb_categories.Category> _categories;
  final IMap<int, pb_groups.Group> _groups;
  final IMap<int, pb_market.MarketGroup> _marketGroups;
  final IMap<int, pb_meta.MetaGroup> _metaGroups;
  final IMap<int, pb_units.DogmaUnit> _dogmaUnits;
  final IMap<int, pb_attrs.DogmaAttribute> _dogmaAttributes;
  final IMap<int, Subsystem> _subsystems;
  final IMap<int, pb_materials.TypeMaterial> _typeMaterials;
  final IMap<int, pb_dynamic.DynamicMutator> _dynamicMutators;
  final IMap<int, pb_dynamic.DynamicTypeOptions> _dynamicTypeOptions;
  final IMap<int, ImplantSet> _implantSets;
  final IMap<int, int> _implantTypeToSet;

  // ── Query surface ──

  Ship? getShip(int typeId) => _ships[typeId];
  pb_types.Type? getType(int typeId) => _types[typeId];
  Slots get slots => _collection.slots;
  IList<pb_types.Type> getAllTypes() => _types.values.toIList();
  IList<int> getSkillTypeIds() => _skillTypeIds;
  IMap<int, int>? getSkillProfile(String id) => _skillProfiles[id];

  pb_categories.Category? getCategory(int categoryId) => _categories[categoryId];
  pb_groups.Group? getGroup(int groupId) => _groups[groupId];
  pb_market.MarketGroup? getMarketGroup(int marketGroupId) => _marketGroups[marketGroupId];
  pb_meta.MetaGroup? getMetaGroup(int metaGroupId) => _metaGroups[metaGroupId];
  pb_units.DogmaUnit? getDogmaUnit(int unitId) => _dogmaUnits[unitId];
  pb_attrs.DogmaAttribute? getDogmaAttribute(int attributeId) => _dogmaAttributes[attributeId];
  IMap<int, pb_attrs.DogmaAttribute> get dogmaAttributes => _dogmaAttributes;
  Subsystem? getSubsystem(int typeId) => _subsystems[typeId];
  pb_materials.TypeMaterial? getTypeMaterial(int typeId) => _typeMaterials[typeId];
  pb_dynamic.DynamicMutator? getDynamicMutator(int mutatorId) => _dynamicMutators[mutatorId];
  pb_dynamic.DynamicTypeOptions? getDynamicTypeOptions(int typeId) => _dynamicTypeOptions[typeId];

  /// Returns the implant set with the given [setId], or `null` when absent
  /// (e.g. older bundles without implant set metadata).
  ImplantSet? getImplantSet(int setId) => _implantSets[setId];

  /// Returns the implant set containing the implant [typeId], or `null` when
  /// the type belongs to no set or set metadata is unavailable.
  ImplantSet? getImplantSetForType(int typeId) {
    final setId = _implantTypeToSet[typeId];
    return setId == null ? null : _implantSets[setId];
  }

  IList<ImplantSet> getAllImplantSets() => _implantSets.values.toIList();

  IList<pb_categories.Category> getAllCategories() => _categories.values.toIList();
  IList<pb_groups.Group> getAllGroups() => _groups.values.toIList();
  IList<pb_market.MarketGroup> getAllMarketGroups() => _marketGroups.values.toIList();
  IList<pb_meta.MetaGroup> getAllMetaGroups() => _metaGroups.values.toIList();

  /// Returns the logical resource path for the icon of [typeId] at the given
  /// [size] (e.g. 32, 64, 128, 256).
  ///
  /// Consumers should resolve the returned value through an `ImageAssetService`
  /// to obtain a displayable image provider.
  String getIconPath(int typeId, int size) {
    final type = _types[typeId];
    if (type == null) return "";

    final icon = type.icon;
    final iconId = icon.hasIconId() ? icon.iconId : null;
    final graphicId = icon.hasGraphicId() ? icon.graphicId : null;

    final id = iconId ?? graphicId;
    if (id == null) return "";

    final iconKey = iconId != null ? "static/images/icons/$iconId.png" : null;
    final graphicKey = graphicId != null ? "static/images/graphics/$graphicId.png" : null;

    return iconKey ?? graphicKey ?? "";
  }

  /// Convenience alias for [getIconPath].
  String getTypeIconPath(int typeId, int size) => getIconPath(typeId, size);
}
