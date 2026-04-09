import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/storage/bundle/service/collection.dart";
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fpdart/fpdart.dart";
import "package:path/path.dart" as p;
import "package:riverpod_annotation/riverpod_annotation.dart";
import "package:uuid/uuid.dart";

part "manager.g.dart";

/// Fit storage is always under global control,
/// So there's no need to maintain a global singleton outside of the Ref tree.
@riverpodSingleton
class FitRegistryManager extends _$FitRegistryManager {
  static String get _fitRegistryPath => p.join(PathProvider.fittingsPath, "registry.json");

  @override
  FitRegistry build() {
    final registryFile = File(_fitRegistryPath);
    if (!registryFile.existsSync()) {
      registryFile
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(encodeFitRegistry(FitRegistry(fits: IMap()))));
    }

    final registryContent = registryFile.readAsStringSync();
    final registryJson = jsonDecode(registryContent) as Map<String, dynamic>;
    final decodedRegistry = decodeFitRegistry(registryJson);
    if (decodedRegistry.didMigrate) {
      registryFile.writeAsStringSync(jsonEncode(encodeFitRegistry(decodedRegistry.registry)));
    }
    final registry = decodedRegistry.registry;
    return registry;
  }

  void updateFit(FitMetadata metadata) {
    debug("Update fit ${metadata.fitId} ${metadata.shipTypeId} in ${metadata.bundleId}");
    state = state.copyWith(fits: state.fits.add(metadata.fitId, metadata));
    _syncToDisk();
  }

  // ignore: unused_element
  void _syncFromDisk() {
    final registryFile = File(_fitRegistryPath);
    if (!registryFile.existsSync()) {
      registryFile
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(encodeFitRegistry(FitRegistry(fits: IMap()))));
    }
    final registryContent = registryFile.readAsStringSync();
    final registryJson = jsonDecode(registryContent) as Map<String, dynamic>;
    final decodedRegistry = decodeFitRegistry(registryJson);
    final registry = decodedRegistry.registry;
    if (decodedRegistry.didMigrate) {
      registryFile.writeAsStringSync(jsonEncode(encodeFitRegistry(registry)));
    }
    state = registry;
  }

  void _syncToDisk() {
    final registryFile = File(_fitRegistryPath);
    if (!registryFile.existsSync()) {
      registryFile.createSync(recursive: true);
    }
    final registryJson = encodeFitRegistry(state);
    final registryContent = jsonEncode(registryJson);
    registryFile.writeAsStringSync(registryContent);
  }
}

@riverpod
Iterable<FitMetadata> fitsForShip(Ref ref, int shipId) =>
    ref.watch(fitRegistryManagerProvider).fits.values.filter((t) => t.shipTypeId == shipId);

@riverpodSingleton
class FitManager extends _$FitManager {
  static const _idGenerator = Uuid();

  @override
  Future<DateTime> build() async {
    ref.read(fitRegistryManagerProvider);
    return DateTime.now();
  }

  static String generateFitId() => _idGenerator.v4();

  Future<FitMetadata> newFit(int shipId, String name) async {
    final ship = ref.watch(
      bundleCollectionServiceProvider.select(
        (collection) => collection.collection?.getShip(shipId),
      ),
    );
    if (ship == null) {
      final text = "Ship with ID $shipId not found in bundle collection.";
      error(text);
      throw Exception(text);
    }
    info("Creating new fit of type $shipId named $name");
    final fitId = generateFitId();
    final bundleInfo = ref.watch(currentBundleProvider.select((t) => t?.metadata));
    if (bundleInfo == null) {
      throw Exception("No bundle is currently loaded.");
    }
    final metadata = FitMetadata(
      fitId: fitId,
      shipTypeId: shipId,
      name: name,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      description: "",
      bundleId: bundleInfo.bundleId,
    );
    final fit = FitStorage.empty(metadata, ship);
    final fitPath = fit.fitStoragePath;
    final path = File(fitPath);
    final text = jsonEncode(encodeFitStorage(fit));
    if (!path.existsSync()) {
      await path.parent.create(recursive: true);
    }
    await path.writeAsString(text);
    ref.read(fitRegistryManagerProvider.notifier).updateFit(metadata);
    return metadata;
  }

  Future<void> deleteFit(String fitId) async {
    final registry = ref.read(fitRegistryManagerProvider);
    final metadata = registry.fits[fitId];
    if (metadata == null) {
      final text = "Fit with ID $fitId not found in registry.";
      error(text);
      throw Exception(text);
    }
    final fitPath = FitStorage.fitStoragePathForId(fitId);
    final path = File(fitPath);
    if (path.existsSync()) {
      await path.delete();
      info("Deleted fit file at $fitPath");
    } else {
      warning("Fit file at $fitPath does not exist.");
    }
    final notifier = ref.read(fitRegistryManagerProvider.notifier);
    notifier
      ..state = notifier.state.copyWith(fits: notifier.state.fits.remove(fitId))
      .._syncToDisk();
  }

  Future<FitMetadata> importFit(FitStorage importedFit) async {
    final ship = ref.watch(
      bundleCollectionServiceProvider.select(
        (collection) => collection.collection?.getShip(importedFit.body.shipTypeId),
      ),
    );
    if (ship == null) {
      final text = "Ship with ID ${importedFit.body.shipTypeId} not found in bundle collection.";
      error(text);
      throw Exception(text);
    }

    final bundleInfo = ref.watch(currentBundleProvider.select((t) => t?.metadata));
    if (bundleInfo == null) {
      throw Exception("No bundle is currently loaded.");
    }

    final fitId = generateFitId();
    final metadata = importedFit.metadata.copyWith(
      fitId: fitId,
      shipTypeId: importedFit.body.shipTypeId,
      name: importedFit.metadata.name.trim().isEmpty
          ? "Imported Fit"
          : importedFit.metadata.name.trim(),
      lastModified: DateTime.now().millisecondsSinceEpoch,
      bundleId: bundleInfo.bundleId,
    );
    final fit = pruneDynamicRegistry(importedFit.copyWith(metadata: metadata));

    final path = File(fit.fitStoragePath);
    final text = jsonEncode(encodeFitStorage(fit));
    if (!path.existsSync()) {
      await path.parent.create(recursive: true);
    }
    await path.writeAsString(text);
    ref.read(fitRegistryManagerProvider.notifier).updateFit(metadata);
    return metadata;
  }
}
