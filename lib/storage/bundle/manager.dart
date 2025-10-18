import 'dart:convert';
import 'dart:io';

import 'package:eve_fit_assistant/config/logger.dart';
import 'package:eve_fit_assistant/config/paths.dart';
import 'package:eve_fit_assistant/storage/bundle/service.dart';
import 'package:eve_fit_assistant/storage/bundle/service/paths.dart';
import 'package:eve_fit_assistant/utils/extract.dart';
import 'package:eve_fit_assistant/utils/riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'manager.freezed.dart';
part 'manager.g.dart';

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

@JsonSerializable()
class BundleRegistry {
  @JsonKey(defaultValue: {})
  Map<String, BundleInfo> bundles;

  BundleRegistry({required this.bundles});
  BundleRegistry.empty() : bundles = {};

  factory BundleRegistry.fromJson(Map<String, dynamic> json) => _$BundleRegistryFromJson(json);

  Map<String, dynamic> toJson() => _$BundleRegistryToJson(this);
}

@riverpodSingleton
class BundleRegistryManager extends _$BundleRegistryManager {
  static String get _bundleRegistryPath => p.join(PathProvider.settingsPath, "bundles.json");
  @override
  BundleRegistry build() {
    final registryFile = File(_bundleRegistryPath);
    if (!registryFile.existsSync()) {
      registryFile.createSync(recursive: true);
      registryFile.writeAsStringSync("{}");
    }

    final registryContent = registryFile.readAsStringSync();
    final registryJson = jsonDecode(registryContent) as Map<String, dynamic>;
    final registry = BundleRegistry.fromJson(registryJson);
    return registry;
  }

  void _syncFromDisk() {
    final registryFile = File(_bundleRegistryPath);
    if (!registryFile.existsSync()) {
      registryFile.createSync(recursive: true);
      registryFile.writeAsStringSync("{}");
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
    debug("Syncing bundle registry data: $registryContent");
    if (!registryFile.existsSync()) {
      registryFile.createSync(recursive: true);
    }
    registryFile.writeAsStringSync(registryContent);
  }

  void _addBundle(BundleInfo bundle) {
    final currentRegistry = state;
    final updatedBundles = Map<String, BundleInfo>.from(currentRegistry.bundles);
    updatedBundles[bundle.bundleId] = bundle;
    final updatedRegistry = BundleRegistry(bundles: updatedBundles);
    _syncToDisk(updatedRegistry);
    state = updatedRegistry;
  }

  void _removeBundle(String bundleId) {
    final currentRegistry = state;
    final updatedBundles = Map<String, BundleInfo>.from(currentRegistry.bundles);
    updatedBundles.remove(bundleId);
    final updatedRegistry = BundleRegistry(bundles: updatedBundles);
    _syncToDisk(updatedRegistry);
    state = updatedRegistry;
  }

  void _clearBundles() {
    final updatedRegistry = BundleRegistry.empty();
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
    ref.read(bundleRegistryManagerProvider);
    ref.read(bundleServiceProvider);
    return DateTime.now();
  }

  Future<void> addBundle(String bundlePath) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final bundleCachePath = Directory(p.join(_bundleCachePath, "cache"));
      if (await bundleCachePath.exists()) {
        bundleCachePath.delete(recursive: true);
        await bundleCachePath.create(recursive: true);
      } else {
        await bundleCachePath.create(recursive: true);
      }
      await extractIsolated(bundlePath, bundleCachePath.path);
      final descriptorPath = BundleServicePaths.descriptorPathFromExternalBundle(
        bundleCachePath.path,
      );
      final content = jsonDecode(await File(descriptorPath).readAsString());
      final BundleDescriptor descriptor;
      try {
        descriptor = BundleDescriptor.fromJson(content);
      } catch (e) {
        warning("Invalid descriptor: $e", stackTrace: StackTrace.current);
        return DateTime.now();
      }
      final bundleId = descriptor.bundleId;
      final baseDir = Directory(_bundleBasePath);
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }
      final targetDir = Directory(p.join(_bundleBasePath, bundleId));
      if (await targetDir.exists()) {
        warning("Target bundle output dir $bundleId exists!");
        return DateTime.now();
      }
      await bundleCachePath.rename(targetDir.path);
      info("Successfully initialized bundle $bundleId: $descriptor");

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
      ref.read(bundleRegistryManagerProvider.notifier)._removeBundle(bundleId);
      return DateTime.now();
    });
  }

  Future<void> clearBundles() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      ref.read(bundleRegistryManagerProvider.notifier)._clearBundles();
      return DateTime.now();
    });
  }

  Future<void> selectBundle(String bundleId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      if (!(ref.read(bundleRegistryManagerProvider)).bundles.containsKey(bundleId)) {
        error("Invalid bundle $bundleId", stackTrace: StackTrace.current);
        throw Exception("Invalid bundle $bundleId");
      }
      return DateTime.now();
    });
  }
}
