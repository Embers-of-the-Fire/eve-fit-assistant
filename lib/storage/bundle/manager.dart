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
    // ignore: invalid_annotation_target
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
    final updatedRegistry = state.copyWith(bundles: state.bundles.remove(bundleId));
    _syncToDisk(updatedRegistry);
    state = updatedRegistry;
  }

  void _selectBundle(String bundleId) {
    final updatedRegistry = state.copyWith(selectedBundleId: bundleId);
    _syncToDisk(updatedRegistry);
    state = updatedRegistry;
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

  Future<void> addBundle(String bundlePath, {Future<bool> Function()? confirmOverwrite}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final bundleCachePath = Directory(p.join(_bundleCachePath, "cache"));
      if (bundleCachePath.existsSync()) {
        await bundleCachePath.delete(recursive: true);
      }
      await bundleCachePath.create(recursive: true);
      await extractIsolated(bundlePath, bundleCachePath.path);
      final descriptorPath = BundleServicePaths.descriptorPathFromExternalBundle(
        bundleCachePath.path,
      );
      final BundleDescriptor descriptor;
      try {
        final content = jsonDecode(await File(descriptorPath).readAsString());
        descriptor = BundleDescriptor.fromJson(ensure(content, {}));
      } catch (e) {
        warning("Invalid descriptor: $e", stackTrace: StackTrace.current);
        return DateTime.now();
      }
      final bundleId = descriptor.bundleId;
      final baseDir = Directory(_bundleBasePath);
      if (!baseDir.existsSync()) {
        await baseDir.create(recursive: true);
      }
      final targetDir = Directory(getBundlePath(bundleId));
      if (!targetDir.existsSync()) {
        if (descriptor.isIncremental) {
          info("Importing incremental bundle $bundleId: $descriptor");
          await copyRecursive(bundleCachePath, targetDir);
        } else {
          warning("Target bundle output dir $bundleId exists!");
          final willOverwrite = await confirmOverwrite?.call() ?? false;
          if (willOverwrite) {
            info("Overwriting existing bundle $bundleId");
            await targetDir.delete(recursive: true);
            await bundleCachePath.rename(targetDir.path);
          } else {
            info("Aborting bundle import for $bundleId");
            return DateTime.now();
          }
        }
      } else {
        await bundleCachePath.rename(targetDir.path);
      }

      final targetRegistrarFile = File(BundleServicePaths(targetDir.path).getRegistrarPath());
      final BundleRegistrar registrar;
      if (!targetRegistrarFile.existsSync()) {
        await targetRegistrarFile.create(recursive: true);
        registrar = BundleRegistrar.empty(bundleId).pushPatch(descriptor);
      } else {
        final registrarContent = jsonDecode(await targetRegistrarFile.readAsString());
        registrar = BundleRegistrar.fromJson(ensure(registrarContent, {})).pushPatch(descriptor);
      }
      final registrarJson = registrar.toJson();
      final registrarContent = const JsonEncoder.withIndent("  ").convert(registrarJson);
      await targetRegistrarFile.writeAsString(registrarContent);

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
      if (updateRegistry) ref.read(bundleRegistryManagerProvider.notifier)._selectBundle(bundleId);
      await ref.read(bundleServiceProvider.notifier).loadBundle(bundleId);
      return DateTime.now();
    });
  }
}
