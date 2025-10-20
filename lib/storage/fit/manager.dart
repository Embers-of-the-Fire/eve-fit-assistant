// ignore_for_file: invalid_annotation_target

import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/data/proto/fit.pb.dart";
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/storage/bundle/service/collection.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:path/path.dart" as p;
import "package:riverpod_annotation/riverpod_annotation.dart";
import "package:uuid/uuid.dart";

part "manager.freezed.dart";
part "manager.g.dart";

@freezed
abstract class FitMetadata with _$FitMetadata {
  const factory FitMetadata({
    required String fitId,
    required int shipTypeId,
    required String name,

    /// DateTime.millisecondsSinceEpoch
    required int lastModified,

    required String description,
    required String bundleId,
  }) = _FitMetadata;

  factory FitMetadata.fromJson(Map<String, dynamic> json) => _$FitMetadataFromJson(json);
}

@freezed
abstract class FitRegistry with _$FitRegistry {
  const factory FitRegistry({
    @JsonKey(defaultValue: IMap.empty) required IMap<String, FitMetadata> fits,
  }) = _FitRegistry;

  factory FitRegistry.fromJson(Map<String, dynamic> json) => _$FitRegistryFromJson(json);
}

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
        ..writeAsStringSync("{}");
    }

    final registryContent = registryFile.readAsStringSync();
    final registryJson = jsonDecode(registryContent) as Map<String, dynamic>;
    final registry = FitRegistry.fromJson(registryJson);
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
        ..writeAsStringSync("{}");
    }
    final registryContent = registryFile.readAsStringSync();
    final registryJson = jsonDecode(registryContent) as Map<String, dynamic>;
    final registry = FitRegistry.fromJson(registryJson);
    state = registry;
  }

  void _syncToDisk() {
    final registryFile = File(_fitRegistryPath);
    if (!registryFile.existsSync()) {
      registryFile.createSync(recursive: true);
    }
    final registryJson = state.toJson();
    final registryContent = jsonEncode(registryJson);
    registryFile.writeAsStringSync(registryContent);
  }
}

@riverpodSingleton
class FitManager extends _$FitManager {
  static const _idGenerator = Uuid();

  @override
  Future<DateTime> build() async {
    ref.read(fitRegistryManagerProvider);
    return DateTime.now();
  }

  static String generateFitId() => _idGenerator.v4();

  Future<void> newFit(int shipId, String name) async {
    Ship? ship;
    for (final s in ref.watch(bundleCollectionProvider).collection.ships) {
      if (s.typeId == shipId) {
        ship = s;
        break;
      }
    }
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
    final text = jsonEncode(fit.toJson());
    if (!path.existsSync()) {
      await path.parent.create(recursive: true);
    }
    await path.writeAsString(text);
    ref.read(fitRegistryManagerProvider.notifier).updateFit(metadata);
  }
}
