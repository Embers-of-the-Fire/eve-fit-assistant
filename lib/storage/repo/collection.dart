import "package:eve_fit_assistant/constant/eve.dart";
import "package:eve_fit_assistant/data/proto/categories.pb.dart" as pb_categories;
import "package:eve_fit_assistant/data/proto/collections.pb.dart";
import "package:eve_fit_assistant/data/proto/dogma_attributes.pb.dart" as pb_attrs;
import "package:eve_fit_assistant/data/proto/dogma_units.pb.dart" as pb_units;
import "package:eve_fit_assistant/data/proto/dynamic.pb.dart" as pb_dynamic;
import "package:eve_fit_assistant/data/proto/fit.pb.dart";
import "package:eve_fit_assistant/data/proto/groups.pb.dart" as pb_groups;
import "package:eve_fit_assistant/data/proto/localizations.pb.dart";
import "package:eve_fit_assistant/data/proto/market_groups.pb.dart" as pb_market;
import "package:eve_fit_assistant/data/proto/meta_groups.pb.dart" as pb_meta;
import "package:eve_fit_assistant/data/proto/type_materials.pb.dart" as pb_materials;
import "package:eve_fit_assistant/data/proto/types.pb.dart" as pb_types;
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/models/asset_manifest.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart"
    show activeCheckoutProvider, assetStoreProvider, checkoutServiceProvider;
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "collection.g.dart";

/// Pre-loaded type data from the active checkout's asset store.
///
/// Built on checkout activation. Provides ship, skill, item, localization,
/// and icon path queries from the content-addressed asset store via the
/// active checkout's manifest.
///
/// Returns `null` when no checkout is active. Clears on deactivation,
/// re-builds on activation.
@riverpodSingleton
RepoCollectionService? repoCollection(Ref ref) {
  final activeOpt = ref.watch(activeCheckoutProvider);
  if (activeOpt.isNone()) return null;
  final active = activeOpt.toNullable()!;
  if (active.checkoutId.isEmpty) return null;

  final manifestOpt = ref.watch(checkoutServiceProvider).readManifest(active.checkoutId);
  if (manifestOpt.isNone()) return null;
  final manifest = manifestOpt.toNullable()!;

  final assetStore = ref.read(assetStoreProvider);

  try {
    return RepoCollectionService._fromManifest(manifest, assetStore);
  } on StateError {
    return null;
  }
}

/// Pre-loaded type data proxy backed by the content-addressed asset store.
///
/// Same query surface reads from the repo's
/// manifest-referenced protobuf files. All data is loaded synchronously at
/// construction from a single `Collection.toBuffer` file and optional per-locale
/// `Localization` files found in the manifest.
class RepoCollectionService {
  const RepoCollectionService._({
    required Collection collection,
    required IMap<String, IMap<int, String>> localizedNames,
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
  }) : _collection = collection,
       _localizedNames = localizedNames,
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
       _dynamicTypeOptions = dynamicTypeOptions;

  /// Builds a [RepoCollectionService] by reading the `collection.pb2` protobuf
  /// and localization files from the asset store via [manifest].
  factory RepoCollectionService._fromManifest(AssetManifest manifest, AssetStore assetStore) {
    // ── Read collection.pb2 ──
    final collectionEntry = manifest.files["static/collection.pb2"];
    if (collectionEntry == null) {
      throw StateError("No collection.pb2 entry in asset manifest");
    }
    final collectionBytes = assetStore.readFileSync(collectionEntry.pathHash, collectionEntry.hash);
    if (collectionBytes.isNone()) {
      throw StateError("collection.pb2 not found in asset store");
    }
    final collection = Collection.fromBuffer(collectionBytes.toNullable()!);

    // ── Build type indexes ──
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

    // ── Derive skill type IDs ──
    final skillGroupIds = collection.groups.values
        .where((group) => group.categoryId == EveConstCategoryId.skill)
        .map((group) => group.groupId)
        .toSet();

    final skillTypeIds = collection.types.values
        .where((type) => skillGroupIds.contains(type.groupId))
        .map((type) => type.typeId)
        .toIList();

    // ── Build skill profiles ──
    final skillProfiles = <String, IMap<int, int>>{};
    for (final entry in collection.skillProfiles.entries) {
      skillProfiles[entry.key] = IMap.fromEntries(
        entry.value.skills.entries.map((e) => MapEntry(e.key, e.value)),
      );
    }

    // ── Build localization maps ──
    final localizedNames = <String, IMap<int, String>>{};
    for (final locale in ["en", "zh"]) {
      final locKey = "localization/localization_$locale.pb2";
      final locEntry = manifest.files[locKey];
      if (locEntry == null) continue;

      final locBytes = assetStore.readFileSync(locEntry.pathHash, locEntry.hash);
      if (locBytes.isSome()) {
        final localization = Localization.fromBuffer(locBytes.toNullable()!);
        localizedNames[locale] = IMap.fromEntries(
          localization.localizedStrings.entries.map((e) => MapEntry(e.key, e.value)),
        );
      }
    }

    return RepoCollectionService._(
      collection: collection,
      localizedNames: localizedNames.toIMap(),
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
    );
  }

  // ── Internal data ──
  final Collection _collection;
  final IMap<String, IMap<int, String>> _localizedNames;

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
  Subsystem? getSubsystem(int typeId) => _subsystems[typeId];
  pb_materials.TypeMaterial? getTypeMaterial(int typeId) => _typeMaterials[typeId];
  pb_dynamic.DynamicMutator? getDynamicMutator(int mutatorId) => _dynamicMutators[mutatorId];
  pb_dynamic.DynamicTypeOptions? getDynamicTypeOptions(int typeId) => _dynamicTypeOptions[typeId];

  IList<pb_categories.Category> getAllCategories() => _categories.values.toIList();
  IList<pb_groups.Group> getAllGroups() => _groups.values.toIList();
  IList<pb_market.MarketGroup> getAllMarketGroups() => _marketGroups.values.toIList();
  IList<pb_meta.MetaGroup> getAllMetaGroups() => _metaGroups.values.toIList();

  /// Returns the localized name for [id] (a type name localization key) in the
  /// given [locale] (e.g. `"en"`, `"zh"`). Returns an empty string when the
  /// locale or key is absent.
  String getLocalizedName(int id, String locale) => _localizedNames[locale]?[id] ?? "";

  /// Returns the asset store identifier for the icon of [typeId] at the given
  /// [size] (e.g. 32, 64, 128, 256), in `"pathHash:contentHash"` format.
  ///
  /// Consumers should resolve the returned value through an [AssetStore] or the
  /// `NativeDirResolver` to obtain a displayable file path or widget.
  String getIconPath(int typeId, int size) {
    final type = _types[typeId];
    if (type == null) return "";

    final icon = type.icon;
    final iconId = icon.hasIconId() ? icon.iconId : null;
    final graphicId = icon.hasGraphicId() ? icon.graphicId : null;

    // Try icon first, then graphic fallback
    final id = iconId ?? graphicId;
    if (id == null) return "";

    // Build a candidate manifest key. The actual file path in the manifest
    // follows the convention `static/images/icons/<id>.png` or
    // `static/images/graphics/<id>.png`.  Since this method returns the
    // asset store identifier token rather than a filesystem path, downstream
    // code resolves it via the manifest's `AssetFile` entries.
    final iconKey = iconId != null ? "static/images/icons/$iconId.png" : null;
    final graphicKey = graphicId != null ? "static/images/graphics/$graphicId.png" : null;

    // We return a token format for consumers to resolve; actual resolution
    // uses the active manifest and AssetStore.
    return iconKey ?? graphicKey ?? "";
  }

  /// Convenience alias for [getIconPath].
  String getTypeIconPath(int typeId, int size) => getIconPath(typeId, size);
}
