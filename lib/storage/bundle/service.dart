import "dart:async";
import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/data/proto/collections.pb.dart";
import "package:eve_fit_assistant/storage/bundle/manager.dart";
import "package:eve_fit_assistant/storage/bundle/service/paths.dart";
import "package:eve_fit_assistant/storage/bundle/skill_profiles.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:eve_fit_assistant/utils/type_check.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fpdart/fpdart.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:path/path.dart" as p;
import "package:riverpod_annotation/riverpod_annotation.dart";

part "service.freezed.dart";
part "service.g.dart";

/// A `BundleDescriptor` is what we see in a bundle zip archive.
/// It's not designed to demonstrate local storage.
@freezed
abstract class BundleDescriptor with _$BundleDescriptor {
  const factory BundleDescriptor({
    required int generateTimestamp,
    @JsonKey(defaultValue: false) required bool isIncremental,
    required String bundleId,
    required String appVersion,
    required String gameVersion,
    required String gameBuild,
    required String gameRegion,
    required String gameBranch,
    required String gameServer,
    String? manifestHash,
    String? baseBundleId,
    String? baseManifestHash,
  }) = _BundleDescriptor;

  factory BundleDescriptor.fromJson(Map<String, dynamic> json) => _$BundleDescriptorFromJson(json);
}

@freezed
abstract class BundleHistoryPatch with _$BundleHistoryPatch {
  const factory BundleHistoryPatch({
    required String appVersion,
    required int generateTimestamp,
    required int loadTimestamp,
    required String gameVersion,
    required String gameBuild,
    required String gameRegion,
    required String gameBranch,
    required String gameServer,
    required bool isIncremental,
    String? manifestHash,
  }) = _BundleHistoryPatch;

  factory BundleHistoryPatch.fromJson(Map<String, dynamic> json) =>
      _$BundleHistoryPatchFromJson(json);
}

@freezed
abstract class BundleRegistrar with _$BundleRegistrar {
  const factory BundleRegistrar({
    required String bundleId,
    required IList<BundleHistoryPatch> history,
  }) = _BundleRegistrar;

  factory BundleRegistrar.empty(String bundleId) =>
      BundleRegistrar(bundleId: bundleId, history: const IList<BundleHistoryPatch>.empty());

  const BundleRegistrar._();

  factory BundleRegistrar.fromJson(Map<String, dynamic> json) => _$BundleRegistrarFromJson(json);

  BundleHistoryPatch get latest => history.last;
  int get lastLoadTimestamp => latest.loadTimestamp;
  BundleRegistrar pushPatch(BundleDescriptor descriptor) {
    final patch = BundleHistoryPatch(
      appVersion: descriptor.appVersion,
      generateTimestamp: descriptor.generateTimestamp,
      loadTimestamp: DateTime.now().millisecondsSinceEpoch,
      manifestHash: descriptor.manifestHash,
      gameVersion: descriptor.gameVersion,
      gameBuild: descriptor.gameBuild,
      gameRegion: descriptor.gameRegion,
      gameBranch: descriptor.gameBranch,
      gameServer: descriptor.gameServer,
      isIncremental: descriptor.isIncremental,
    );
    return copyWith(history: patch.isIncremental ? history.add(patch) : [patch].lock);
  }
}

@freezed
abstract class BundleMetadata with _$BundleMetadata {
  const factory BundleMetadata({
    required String bundleId,
    required BundleServicePaths paths,
    required DateTime lastModified,
    required BundleRegistrar metadata,
  }) = _BundleMetadata;
}

@freezed
class CurrentBundleStatus with _$CurrentBundleStatus {
  const factory CurrentBundleStatus.notSelected() = _CurrentBundleStatusNotSelected;
  const factory CurrentBundleStatus.initializing({required String bundleId}) =
      _CurrentBundleStatusInitializing;
  const factory CurrentBundleStatus.error({required IList<BundleValidationError> errors}) =
      _CurrentBundleStatusError;

  const factory CurrentBundleStatus.loaded({required BundleMetadata data}) =
      _CurrentBundleStatusLoaded;

  const CurrentBundleStatus._();

  Option<BundleMetadata> get currentData => switch (this) {
    _CurrentBundleStatusLoaded(:final data) => Option.of(data),
    _ => const Option.none(),
  };

  bool get selected => switch (this) {
    _CurrentBundleStatusNotSelected() => false,
    _ => true,
  };
  bool get isInitializing => switch (this) {
    _CurrentBundleStatusInitializing(bundleId: _) => true,
    _ => false,
  };
  bool get isLoaded => switch (this) {
    _CurrentBundleStatusLoaded(data: _) => true,
    _ => false,
  };

  String? get bundleId => switch (this) {
    _CurrentBundleStatusInitializing(bundleId: final id) => id,
    _CurrentBundleStatusLoaded(data: final data) => data.bundleId,
    _ => null,
  };
}

/// Access the currently loaded bundle data.
/// Returns `null` if no bundle is loaded.
@riverpodSingleton
BundleMetadata? currentBundle(Ref ref) {
  ref.watch(bundleServiceProvider);
  return ref.read(bundleServiceProvider.notifier).currentBundleData;
}

/// Serves bundle data.
/// UI should access this via [`currentBundleProvider`][currentBundle] rather than directly.
@riverpodSingleton
class BundleService extends _$BundleService {
  Future<CurrentBundleStatus>? _pendingLoad;
  BundleMetadata? _mountedBundle;
  Collection? _mountedCollection;
  String? _pendingBundleId;
  int _loadGeneration = 0;

  BundleMetadata? get currentBundleData => _mountedBundle;
  String? get pendingBundleId => _pendingBundleId;

  Collection? collectionForBundle(String bundleId) {
    if (_mountedBundle?.bundleId != bundleId) {
      return null;
    }
    return _mountedCollection;
  }

  @override
  CurrentBundleStatus build() {
    final selectedBundleId = ref.read(bundleRegistryManagerProvider).selectedBundleId;
    if (selectedBundleId != null) {
      unawaited(
        Future<void>(() async {
          try {
            await loadBundle(selectedBundleId);
          } on Object catch (errorValue, stackTrace) {
            error(
              "Failed to load selected bundle during startup: $selectedBundleId",
              error: errorValue,
              stackTrace: stackTrace,
            );
            // Startup keeps the service state as the source of truth.
          }
        }),
      );
    }
    return const CurrentBundleStatus.notSelected();
  }

  void clearSelection() {
    _mountedBundle = null;
    _mountedCollection = null;
    _pendingBundleId = null;
    _pendingLoad = null;
    _loadGeneration++;
    state = const CurrentBundleStatus.notSelected();
  }

  Future<CurrentBundleStatus> loadBundle(String bundleId) async {
    final mountedBundle = _mountedBundle;
    if (mountedBundle != null && mountedBundle.bundleId == bundleId && _pendingBundleId == null) {
      state = CurrentBundleStatus.loaded(data: mountedBundle);
      return state;
    }

    final pendingLoad = _pendingLoad;
    if (pendingLoad != null && _pendingBundleId == bundleId) {
      return pendingLoad;
    }

    final loadGeneration = ++_loadGeneration;
    final load = _loadBundle(bundleId, loadGeneration: loadGeneration);
    _pendingLoad = load;
    _pendingBundleId = bundleId;
    state = CurrentBundleStatus.initializing(bundleId: bundleId);

    try {
      return await load;
    } finally {
      if (identical(_pendingLoad, load) && _loadGeneration == loadGeneration) {
        _pendingLoad = null;
        _pendingBundleId = null;
      }
    }
  }

  Future<CurrentBundleStatus> _loadBundle(String bundleId, {required int loadGeneration}) async {
    final mountedBundle = _mountedBundle;
    final bundlePath = p.join(PathProvider.resourcesPath, "bundles", bundleId);
    final bundlePathService = BundleServicePaths(bundlePath);
    final errors = await bundlePathService.validate();
    if (errors.isNotEmpty) {
      if (_isCurrentLoad(bundleId, loadGeneration)) {
        _restoreMountedBundleOrError(mountedBundle, errors);
      }
      throw _BundleLoadFailure(errors);
    }

    final registrarPath = File(bundlePathService.getRegistrarPath());
    try {
      final json = jsonDecode(await registrarPath.readAsString());
      final registrar = BundleRegistrar.fromJson(ensure(json, {}));
      final registrarErrors = <BundleValidationError>[
        if (registrar.bundleId != bundleId)
          const BundleValidationError.badPatch(reason: "Bundle id does not match registrar."),
        if (registrar.history.isEmpty)
          const BundleValidationError.badPatch(reason: "Bundle history is empty."),
      ].lock;
      if (registrarErrors.isNotEmpty) {
        if (_isCurrentLoad(bundleId, loadGeneration)) {
          _restoreMountedBundleOrError(mountedBundle, registrarErrors);
        }
        throw _BundleLoadFailure(registrarErrors);
      }
      final collectionResult = await _loadAndValidateCollection(
        bundlePathService.getCollectionPath(),
      );
      if (collectionResult.errors.isNotEmpty) {
        if (_isCurrentLoad(bundleId, loadGeneration)) {
          _restoreMountedBundleOrError(mountedBundle, collectionResult.errors);
        }
        throw _BundleLoadFailure(collectionResult.errors);
      }
      if (_isCurrentLoad(bundleId, loadGeneration)) {
        final nextMountedBundle = BundleMetadata(
          metadata: registrar,
          bundleId: bundleId,
          paths: bundlePathService,
          lastModified: DateTime.now(),
        );
        _mountedBundle = nextMountedBundle;
        _mountedCollection = collectionResult.collection;
        state = CurrentBundleStatus.loaded(data: nextMountedBundle);
      }
    } on _BundleLoadFailure {
      rethrow;
    } catch (e) {
      final descriptorErrors = errors.add(BundleValidationError.badDescriptor(error: e));
      if (_isCurrentLoad(bundleId, loadGeneration)) {
        _restoreMountedBundleOrError(mountedBundle, descriptorErrors);
      }
      throw _BundleLoadFailure(descriptorErrors);
    }
    return state;
  }

  bool _isCurrentLoad(String bundleId, int loadGeneration) =>
      _pendingBundleId == bundleId && _loadGeneration == loadGeneration;

  Future<({Collection? collection, IList<BundleValidationError> errors})>
  _loadAndValidateCollection(String collectionPath) async {
    try {
      final collection = Collection.fromBuffer(await File(collectionPath).readAsBytes());
      final missingProfileIds = requiredBundleSkillProfileIds
          .where((profileId) => !collection.skillProfiles.containsKey(profileId))
          .toIList();
      if (missingProfileIds.isNotEmpty) {
        return (
          collection: null,
          errors: [
            BundleValidationError.badPatch(
              reason:
                  "Bundle collection is missing skill profiles: ${missingProfileIds.join(", ")}",
            ),
          ].lock,
        );
      }
      return (collection: collection, errors: const IList<BundleValidationError>.empty());
    } on Object catch (e) {
      return (collection: null, errors: [BundleValidationError.badDescriptor(error: e)].lock);
    }
  }

  void _restoreMountedBundleOrError(
    BundleMetadata? mountedBundle,
    IList<BundleValidationError> errors,
  ) {
    if (mountedBundle != null) {
      _mountedBundle = mountedBundle;
      state = CurrentBundleStatus.loaded(data: mountedBundle);
      return;
    }

    _mountedBundle = null;
    _mountedCollection = null;
    state = CurrentBundleStatus.error(errors: errors);
  }
}

class _BundleLoadFailure implements Exception {
  const _BundleLoadFailure(this.errors);

  final IList<BundleValidationError> errors;
}

@freezed
abstract class BundleValidationError with _$BundleValidationError {
  const factory BundleValidationError.missingPath({required String path}) =
      _BundleValidationErrorMissingPath;
  const factory BundleValidationError.expectFile({required String fileName}) =
      _BundleValidationErrorExpectFile;
  const factory BundleValidationError.expectDirectory({required String dirName}) =
      _BundleValidationErrorExpectDirectory;

  const factory BundleValidationError.badDescriptor({required Object error}) =
      _BundleValidationErrorBadDescriptor;
  const factory BundleValidationError.badPatch({required String reason}) =
      _BundleValidationErrorBadPatch;
}
