import "dart:async";
import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/bundle/manager.dart";
import "package:eve_fit_assistant/storage/bundle/service/paths.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:eve_fit_assistant/utils/type_check.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
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
    // ignore: invalid_annotation_target
    @JsonKey(defaultValue: false) required bool isIncremental,
    required String bundleId,
    required String appVersion,
    required String gameVersion,
    required String gameBuild,
    required String gameRegion,
    required String gameBranch,
    required String gameServer,
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
/// Throws if no bundle is loaded.
@riverpodSingleton
BundleMetadata? currentBundle(Ref ref) => ref.watch(bundleServiceProvider).currentData.nullable;

/// Serves bundle data.
/// UI should access this via [`currentBundleProvider`][currentBundle] rather than directly.
@riverpodSingleton
class BundleService extends _$BundleService {
  @override
  CurrentBundleStatus build() {
    if (ref.read(bundleRegistryManagerProvider.select((value) => value.selectedBundleId)) != null) {
      unawaited(loadBundle(ref.read(bundleRegistryManagerProvider).selectedBundleId!));
    }
    ref.listen(bundleRegistryManagerProvider.select((value) => value.selectedBundleId), (
      prev,
      next,
    ) {
      if (next == prev) return;
      if (next == null) {
        state = const CurrentBundleStatus.notSelected();
        return;
      }
      unawaited(loadBundle(ref.read(bundleRegistryManagerProvider).selectedBundleId!));
    });
    return const CurrentBundleStatus.notSelected();
  }

  Future<CurrentBundleStatus> loadBundle(String bundleId) async {
    state = CurrentBundleStatus.initializing(bundleId: bundleId);
    final bundlePath = p.join(PathProvider.resourcesPath, "bundles", bundleId);
    final bundlePathService = BundleServicePaths(bundlePath);
    final errors = await bundlePathService.validate();
    final registrarPath = File(bundlePathService.getRegistrarPath());
    if (!registrarPath.existsSync()) {
      state = CurrentBundleStatus.error(errors: errors);
    }
    final json = jsonDecode(await registrarPath.readAsString());
    try {
      final registrar = BundleRegistrar.fromJson(ensure(json, {}));
      state = CurrentBundleStatus.loaded(
        data: BundleMetadata(
          metadata: registrar,
          bundleId: bundleId,
          paths: bundlePathService,
          lastModified: DateTime.now(),
        ),
      );
    } catch (e) {
      state = CurrentBundleStatus.error(
        errors: errors.add(BundleValidationError.badDescriptor(error: e)),
      );
    }
    return state;
  }
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
}
