import "dart:convert";
import "dart:io";

import "package:crypto/crypto.dart";
import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/remote_content/endpoint.dart";
import "package:eve_fit_assistant/storage/bundle/impact.dart";
import "package:eve_fit_assistant/storage/bundle/remote_catalog.dart";
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/storage/bundle/service/paths.dart";
import "package:eve_fit_assistant/storage/character/manager.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
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

  static BundleRegistry _normalizeRegistry(BundleRegistry registry) {
    final bundles = <String, BundleInfo>{
      for (final entry in registry.bundles.entries)
        if (Directory(BundleManager.getBundlePath(entry.key)).existsSync()) entry.key: entry.value,
    }.lock;
    final selectedBundleId = switch (registry.selectedBundleId) {
      final bundleId? when bundles.containsKey(bundleId) => bundleId,
      _ when bundles.isNotEmpty => bundles.keys.first,
      _ => null,
    };
    return registry.copyWith(bundles: bundles, selectedBundleId: selectedBundleId);
  }

  void _setRegistry(BundleRegistry registry) {
    _syncToDisk(registry);
    state = registry;
  }

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
    final registry = _normalizeRegistry(BundleRegistry.fromJson(registryJson));
    _syncToDisk(registry);
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
    final updatedRegistry = _normalizeRegistry(
      state.copyWith(
        bundles: state.bundles.add(bundle.bundleId, bundle),
        selectedBundleId: state.selectedBundleId,
      ),
    );
    _setRegistry(updatedRegistry);
  }

  BundleRegistry _removeBundle(String bundleId) {
    final updatedRegistry = _normalizeRegistry(
      state.copyWith(
        bundles: state.bundles.remove(bundleId),
        selectedBundleId: bundleId == state.selectedBundleId ? null : state.selectedBundleId,
      ),
    );
    _setRegistry(updatedRegistry);
    return updatedRegistry;
  }

  BundleRegistry _selectBundle(String bundleId) {
    final updatedRegistry = _normalizeRegistry(state.copyWith(selectedBundleId: bundleId));
    _setRegistry(updatedRegistry);
    return updatedRegistry;
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
  static String get _remoteDownloadCachePath => p.join(_bundleCachePath, "remote");
  static const Duration _remoteDownloadConnectTimeout = Duration(seconds: 30);
  static const Duration _remoteDownloadSendTimeout = Duration(seconds: 30);
  static const Duration _remoteDownloadReceiveTimeout = Duration(minutes: 5);

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

  Future<void> addBundle(
    String bundlePath, {
    Future<bool> Function()? confirmOverwrite,
    Future<bool> Function(BundleImpactReport report)? confirmIncrementalImpact,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _addBundleFromPath(
        bundlePath,
        confirmOverwrite: confirmOverwrite,
        confirmIncrementalImpact: confirmIncrementalImpact,
      ),
    );
  }

  Future<DateTime> _addBundleFromPath(
    String bundlePath, {
    Future<bool> Function()? confirmOverwrite,
    Future<bool> Function(BundleImpactReport report)? confirmIncrementalImpact,
  }) async {
    late final _PreparedBundleArtifact artifact;
    try {
      artifact = await _prepareBundleArtifact(bundlePath);
    } catch (e) {
      warning("Invalid bundle artifact: $e", stackTrace: StackTrace.current);
      throw StateError("Invalid bundle artifact: $e");
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
        final patchHasPayload = await _incrementalPatchHasPayload(
          bundleCachePath,
          artifact.deletedFiles,
        );
        if (patchHasPayload) {
          final report = analyzeBundleImpact(
            fitRegistry: ref.read(fitRegistryManagerProvider),
            characterRegistry: ref.read(characterRegistryManagerProvider),
            target: BundleImpactTarget(
              kind: BundleImpactTargetKind.incrementalImport,
              sourceBundle: BundleMetadata(
                bundleId: bundleId,
                paths: BundleServicePaths(targetDir.path),
                lastModified: DateTime.now(),
                metadata: registrar,
              ),
              targetBundle: bundleMetadataFromDescriptor(
                descriptor: descriptor,
                registrar: registrar,
                paths: BundleServicePaths(targetDir.path),
              ),
              incrementalPatchHasPayload: true,
            ),
          );
          final confirmed = await confirmIncrementalImpact?.call(report) ?? true;
          if (!confirmed) {
            info("Aborting incremental bundle import for $bundleId");
            return DateTime.now();
          }
        }
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
  }

  Future<void> addRemoteBundle(
    RemoteBundleArtifact artifact, {
    Future<bool> Function()? confirmOverwrite,
    Future<bool> Function(BundleImpactReport report)? confirmIncrementalImpact,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final config = ref.read(appSettingServiceProvider).remoteContent;
      if (!config.enabled) {
        throw StateError("Remote content is disabled.");
      }

      _validateRemoteIncrementalCompatibility(artifact);
      final endpoint = RemoteContentEndpoint.fromSetting(config);
      final artifactUri = endpoint.resolvePayloadUri(artifact.artifactPath);
      final localPath = await _downloadRemoteArtifact(artifact, artifactUri);
      try {
        return await _addBundleFromPath(
          localPath,
          confirmOverwrite: confirmOverwrite,
          confirmIncrementalImpact: confirmIncrementalImpact,
        );
      } finally {
        final file = File(localPath);
        if (file.existsSync()) {
          await file.delete();
        }
      }
    });
  }

  void _validateRemoteIncrementalCompatibility(RemoteBundleArtifact artifact) {
    if (!artifact.isIncremental) {
      return;
    }
    final baseBundleId = artifact.baseBundleId;
    final baseManifestHash = artifact.baseManifestHash;
    if (baseBundleId == null || baseManifestHash == null) {
      throw StateError("Remote incremental bundle is missing base metadata.");
    }
    final registrar = BundleRegistryManager.getRegistrar(baseBundleId);
    final installedManifestHash = registrar.latest.manifestHash;
    if (installedManifestHash == null) {
      throw StateError("Installed bundle is missing manifest hash metadata.");
    }
    if (installedManifestHash != baseManifestHash) {
      throw StateError(
        "Remote incremental bundle base manifest mismatch: "
        "$baseManifestHash != $installedManifestHash",
      );
    }
  }

  Future<String> _downloadRemoteArtifact(RemoteBundleArtifact artifact, Uri uri) async {
    final cacheDir = Directory(_remoteDownloadCachePath);
    await cacheDir.create(recursive: true);
    final targetFile = File(p.join(cacheDir.path, "${artifact.artifactId}.zip"));
    if (targetFile.existsSync()) {
      await targetFile.delete();
    }

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: _remoteDownloadConnectTimeout,
          sendTimeout: _remoteDownloadSendTimeout,
          receiveTimeout: _remoteDownloadReceiveTimeout,
        ),
      );
      await dio.downloadUri(uri, targetFile.path);
    } on DioException catch (exception) {
      final response = exception.response;
      final status = response?.statusCode;
      throw StateError(
        "Remote bundle download failed for $uri"
        "${status == null ? "" : " with HTTP $status"}.",
      );
    }

    final actualSize = await targetFile.length();
    if (actualSize != artifact.artifactSize) {
      throw StateError(
        "Remote bundle size mismatch: expected ${artifact.artifactSize}, got $actualSize.",
      );
    }

    final actualHash = (await sha256.bind(targetFile.openRead()).first).toString();
    if (actualHash != artifact.artifactSha256) {
      throw StateError(
        "Remote bundle SHA-256 mismatch: expected ${artifact.artifactSha256}, got $actualHash.",
      );
    }
    return targetFile.path;
  }

  static Future<bool> _incrementalPatchHasPayload(
    Directory bundleCachePath,
    IList<String> deletedFiles,
  ) async {
    if (deletedFiles.isNotEmpty) {
      return true;
    }
    await for (final entity in bundleCachePath.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final relativePath = p.relative(entity.path, from: bundleCachePath.path);
      if (relativePath == "descriptor.json" ||
          relativePath == "manifest.json" ||
          relativePath == "deleted_files.json") {
        continue;
      }
      return true;
    }
    return false;
  }

  Future<void> removeBundle(String bundleId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final activeBundleId = ref.read(currentBundleProvider)?.bundleId;
      final targetDir = Directory(getBundlePath(bundleId));
      if (targetDir.existsSync()) {
        await targetDir.delete(recursive: true);
        info("Removed bundle directory for $bundleId");
      } else {
        warning("Bundle directory for $bundleId does not exist");
      }

      final updatedRegistry = ref
          .read(bundleRegistryManagerProvider.notifier)
          ._removeBundle(bundleId);
      if (activeBundleId == bundleId) {
        final replacementBundleId = updatedRegistry.selectedBundleId;
        if (replacementBundleId == null) {
          ref.read(bundleServiceProvider.notifier).clearSelection();
        } else {
          await ref.read(bundleServiceProvider.notifier).loadBundle(replacementBundleId);
        }
      }
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

      await ref.read(bundleServiceProvider.notifier).loadBundle(bundleId);
      if (updateRegistry) {
        ref.read(bundleRegistryManagerProvider.notifier)._selectBundle(bundleId);
      }
      return DateTime.now();
    });
  }
}
