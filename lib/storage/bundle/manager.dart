import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/storage/bundle/service/paths.dart";
import "package:eve_fit_assistant/utils/extract.dart";
import "package:eve_fit_assistant/utils/file.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:eve_fit_assistant/utils/type_check.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:path/path.dart" as p;
import "package:riverpod_annotation/riverpod_annotation.dart";

part "manager.freezed.dart";
part "manager.g.dart";

class _PreparedBundleArtifact {
  const _PreparedBundleArtifact({
    required this.cachePath,
    required this.descriptor,
    required this.deletedFiles,
  });

  final Directory cachePath;
  final BundleDescriptor descriptor;
  final IList<String> deletedFiles;
}

@freezed
abstract class BundleInfo with _$BundleInfo {
  const factory BundleInfo({
    required String bundleId,
    required String version,
    required String build,
    required String region,
  }) = _BundleInfo;

  factory BundleInfo.fromJson(Map<String, dynamic> json) => _$BundleInfoFromJson(json);
}

@freezed
abstract class BundleRegistry with _$BundleRegistry {
  const factory BundleRegistry({
    @JsonKey(defaultValue: IMap.empty) required IMap<String, BundleInfo> bundles,
    String? selectedBundleId,
  }) = _BundleRegistry;

  factory BundleRegistry.fromJson(Map<String, dynamic> json) => _$BundleRegistryFromJson(json);
}

@riverpodSingleton
class BundleRegistryManager extends _$BundleRegistryManager {
  static String get _bundleRegistryPath => p.join(PathProvider.resourcesPath, "bundles.json");
  @override
  BundleRegistry build() {
    final registryFile = File(_bundleRegistryPath);
    if (!registryFile.existsSync()) {
      registryFile
        ..createSync(recursive: true)
        ..writeAsStringSync("{}");
    }

    final registryContent = registryFile.readAsStringSync();
    final registryJson = jsonDecode(registryContent) as Map<String, dynamic>;
    final registry = BundleRegistry.fromJson(registryJson);
    return registry;
  }

  // ignore: unused_element
  void _syncFromDisk() {
    final registryFile = File(_bundleRegistryPath);
    if (!registryFile.existsSync()) {
      registryFile
        ..createSync(recursive: true)
        ..writeAsStringSync("{}");
    }
    final registryContent = registryFile.readAsStringSync();
    final registryJson = jsonDecode(registryContent) as Map<String, dynamic>;
    final registry = BundleRegistry.fromJson(registryJson);
    state = registry;
  }

  static void _syncToDisk(BundleRegistry registry) {
    final registryFile = File(_bundleRegistryPath);
    final registryJson = registry.toJson();
    final registryContent = const JsonEncoder.withIndent("  ").convert(registryJson);
    if (!registryFile.existsSync()) {
      registryFile.createSync(recursive: true);
    }
    registryFile.writeAsStringSync(registryContent);
  }

  void _addBundle(BundleInfo bundle) {
    final updatedRegistry = state.copyWith(bundles: state.bundles.add(bundle.bundleId, bundle));
    _syncToDisk(updatedRegistry);
    state = updatedRegistry;
  }

  void _removeBundle(String bundleId) {
    final updatedRegistry = state.copyWith(
      bundles: state.bundles.remove(bundleId),
      selectedBundleId: bundleId == state.selectedBundleId ? null : state.selectedBundleId,
    );
    _syncToDisk(updatedRegistry);
    state = updatedRegistry;
  }

  void _selectBundle(String bundleId) {
    final updatedRegistry = state.copyWith(selectedBundleId: bundleId);
    _syncToDisk(updatedRegistry);
    state = updatedRegistry;
  }

  static BundleRegistrar getRegistrar(String bundleId) {
    final file = BundleServicePaths(BundleManager.getBundlePath(bundleId)).getRegistrarPath();
    final content = File(file).readAsStringSync();
    final reg = BundleRegistrar.fromJson(ensure(jsonDecode(content), {}));
    return reg;
  }
}

@riverpodSingleton
class BundleManager extends _$BundleManager {
  static String get _bundleBasePath => p.join(PathProvider.resourcesPath, "bundles");
  static String get _bundleCachePath => p.join(PathProvider.cacheResourcesPath, "bundles");

  @override
  Future<DateTime> build() async {
    ref
      ..read(bundleRegistryManagerProvider)
      ..read(bundleServiceProvider);
    return DateTime.now();
  }

  static String getBundlePath(String bundleId) => p.join(_bundleBasePath, bundleId);

  static Future<BundleDescriptor> _readDescriptor(String bundlePath) async {
    final descriptorPath = BundleServicePaths.descriptorPathFromExternalBundle(bundlePath);
    final content = jsonDecode(await File(descriptorPath).readAsString());
    return BundleDescriptor.fromJson(ensure(content, {}));
  }

  static Future<IList<String>> _readDeletedFiles(String bundlePath) async {
    final deletedFilesPath = BundleServicePaths.deletedFilesPathFromExternalBundle(bundlePath);
    final deletedFilesFile = File(deletedFilesPath);
    if (!deletedFilesFile.existsSync()) {
      return const IList<String>.empty();
    }

    final content = jsonDecode(await deletedFilesFile.readAsString());
    final files = ensure<List<dynamic>>(content, <dynamic>[]).whereType<String>().toIList();
    return files;
  }

  static Future<BundleRegistrar> _readRegistrar(Directory targetDir) async {
    final registrarPath = BundleServicePaths(targetDir.path).getRegistrarPath();
    final registrarContent = jsonDecode(await File(registrarPath).readAsString());
    return BundleRegistrar.fromJson(ensure(registrarContent, {}));
  }

  static Future<void> _writeRegistrar(Directory targetDir, BundleRegistrar registrar) async {
    final targetRegistrarFile = File(BundleServicePaths(targetDir.path).getRegistrarPath());
    await targetRegistrarFile.create(recursive: true);
    final registrarContent = const JsonEncoder.withIndent("  ").convert(registrar.toJson());
    await targetRegistrarFile.writeAsString(registrarContent);
  }

  static void _validateIncrementalCompatibility(
    BundleDescriptor descriptor,
    BundleRegistrar registrar,
  ) {
    if (descriptor.baseBundleId != null && descriptor.baseBundleId != registrar.bundleId) {
      throw StateError(
        "Incremental bundle base bundle id mismatch: "
        "${descriptor.baseBundleId} != ${registrar.bundleId}",
      );
    }
    if (descriptor.baseManifestHash == null) {
      throw StateError("Incremental bundle is missing base manifest hash.");
    }

    final installedManifestHash = registrar.latest.manifestHash;
    if (installedManifestHash == null) {
      throw StateError("Installed bundle is missing manifest hash metadata.");
    }
    if (installedManifestHash != descriptor.baseManifestHash) {
      throw StateError(
        "Incremental bundle base manifest mismatch: "
        "${descriptor.baseManifestHash} != $installedManifestHash",
      );
    }
  }

  static Future<_PreparedBundleArtifact> _prepareBundleArtifact(String bundlePath) async {
    final bundleCachePath = Directory(p.join(_bundleCachePath, "cache"));
    if (bundleCachePath.existsSync()) {
      await bundleCachePath.delete(recursive: true);
    }
    await bundleCachePath.create(recursive: true);
    await extractIsolated(bundlePath, bundleCachePath.path);

    final descriptor = await _readDescriptor(bundleCachePath.path);
    final deletedFiles = await _readDeletedFiles(bundleCachePath.path);
    return _PreparedBundleArtifact(
      cachePath: bundleCachePath,
      descriptor: descriptor,
      deletedFiles: deletedFiles,
    );
  }

  Future<void> addBundle(String bundlePath, {Future<bool> Function()? confirmOverwrite}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      late final _PreparedBundleArtifact artifact;
      try {
        artifact = await _prepareBundleArtifact(bundlePath);
      } catch (e) {
        warning("Invalid bundle artifact: $e", stackTrace: StackTrace.current);
        return DateTime.now();
      }

      final bundleCachePath = artifact.cachePath;
      final descriptor = artifact.descriptor;
      final bundleId = descriptor.bundleId;
      final baseDir = Directory(_bundleBasePath);
      if (!baseDir.existsSync()) {
        await baseDir.create(recursive: true);
      }
      final targetDir = Directory(getBundlePath(bundleId));
      if (targetDir.existsSync()) {
        if (descriptor.isIncremental) {
          final registrar = await _readRegistrar(targetDir);
          _validateIncrementalCompatibility(descriptor, registrar);
          info("Importing incremental bundle $bundleId: $descriptor");
          await deletePaths(targetDir, artifact.deletedFiles);
          final deletedFilesPath = File(
            BundleServicePaths.deletedFilesPathFromExternalBundle(bundleCachePath.path),
          );
          if (deletedFilesPath.existsSync()) {
            await deletedFilesPath.delete();
          }
          await copyRecursive(bundleCachePath, targetDir);
          await _writeRegistrar(targetDir, registrar.pushPatch(descriptor));
        } else {
          warning("Target bundle output dir $bundleId exists!");
          final willOverwrite = await confirmOverwrite?.call() ?? false;
          if (willOverwrite) {
            info("Overwriting existing bundle $bundleId");
            await targetDir.delete(recursive: true);
            await bundleCachePath.rename(targetDir.path);
            await _writeRegistrar(targetDir, BundleRegistrar.empty(bundleId).pushPatch(descriptor));
          } else {
            info("Aborting bundle import for $bundleId");
            return DateTime.now();
          }
        }
      } else {
        if (descriptor.isIncremental) {
          throw StateError("Cannot import incremental bundle without an installed base bundle.");
        }
        await bundleCachePath.rename(targetDir.path);
        await _writeRegistrar(targetDir, BundleRegistrar.empty(bundleId).pushPatch(descriptor));
      }

      info("Successfully imported bundle $bundleId: $descriptor");

      ref
          .read(bundleRegistryManagerProvider.notifier)
          ._addBundle(
            BundleInfo(
              bundleId: descriptor.bundleId,
              version: descriptor.appVersion,
              build: descriptor.gameBuild,
              region: descriptor.gameRegion,
            ),
          );
      ref.invalidate(bundleServiceProvider);

      return DateTime.now();
    });
  }

  Future<void> removeBundle(String bundleId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final targetDir = Directory(getBundlePath(bundleId));
      if (targetDir.existsSync()) {
        await targetDir.delete(recursive: true);
        info("Removed bundle directory for $bundleId");
      } else {
        warning("Bundle directory for $bundleId does not exist");
      }
      ref.read(bundleRegistryManagerProvider.notifier)._removeBundle(bundleId);
      final _ = ref.refresh(currentBundleProvider);
      return DateTime.now();
    });
  }

  Future<void> selectBundle(String bundleId, {bool updateRegistry = true}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      if (!ref.read(bundleRegistryManagerProvider).bundles.containsKey(bundleId)) {
        error("Invalid bundle $bundleId", stackTrace: StackTrace.current);
        throw Exception("Invalid bundle $bundleId");
      }
      debug("Select new global bundle $bundleId");
      if (updateRegistry) ref.read(bundleRegistryManagerProvider.notifier)._selectBundle(bundleId);
      return DateTime.now();
    });
  }
}
