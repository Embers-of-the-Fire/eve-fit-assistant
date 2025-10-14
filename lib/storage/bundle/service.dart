import 'dart:convert';
import 'dart:io';

import 'package:eve_fit_assistant/config/paths.dart';
import 'package:eve_fit_assistant/storage/bundle/service/paths.dart';
import 'package:eve_fit_assistant/utils/fp.dart';
import 'package:eve_fit_assistant/utils/riverpod.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'service.freezed.dart';
part 'service.g.dart';

@freezed
abstract class BundleDescriptor with _$BundleDescriptor {
  const factory BundleDescriptor({
    required int generateTimestamp,
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
abstract class BundleMetadata with _$BundleMetadata {
  const factory BundleMetadata({
    required String bundleId,
    required BundleServicePaths paths,
    required DateTime lastModified,
    required BundleDescriptor descriptor,
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
    _ => Option.none(),
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
BundleMetadata currentBundle(Ref ref) =>
    (ref.watch(bundleServiceProvider).currentData).unwrap("Bundle not loaded");

/// Serves bundle data.
/// UI should access this via [`currentBundleProvider`][currentBundle] rather than directly.
@riverpodSingleton
class BundleService extends _$BundleService {
  @override
  CurrentBundleStatus build() {
    return CurrentBundleStatus.notSelected();
  }

  Future<CurrentBundleStatus> loadBundle(String bundleId) async {
    state = CurrentBundleStatus.initializing(bundleId: bundleId);
    final bundlePath = p.join(PathProvider.resourcesPath, "bundles", bundleId);
    final bundlePathService = BundleServicePaths(bundlePath);
    final errors = await bundlePathService.validate();
    final descriptorFile = File(bundlePathService.getDescriptorPath());
    if (!await descriptorFile.exists()) {
      state = CurrentBundleStatus.error(errors: errors);
    }
    final json = jsonDecode(await descriptorFile.readAsString());
    try {
      final descriptor = BundleDescriptor.fromJson(json);
      state = CurrentBundleStatus.loaded(
        data: BundleMetadata(
          descriptor: descriptor,
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
