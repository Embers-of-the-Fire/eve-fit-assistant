import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/bundle/manager.dart";
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:path/path.dart" as p;

class StartupPersistenceRepairReport {
  const StartupPersistenceRepairReport({
    required this.rewroteFitRegistry,
    required this.rewroteBundleRegistry,
    required this.removedMissingFitEntries,
    required this.restoredFitEntries,
    required this.unrestoredFitFiles,
    required this.removedMissingBundleEntries,
    required this.restoredBundleEntries,
    required this.selectedBundleChanged,
  });

  const StartupPersistenceRepairReport.empty()
    : rewroteFitRegistry = false,
      rewroteBundleRegistry = false,
      removedMissingFitEntries = 0,
      restoredFitEntries = 0,
      unrestoredFitFiles = 0,
      removedMissingBundleEntries = 0,
      restoredBundleEntries = 0,
      selectedBundleChanged = false;

  final bool rewroteFitRegistry;
  final bool rewroteBundleRegistry;
  final int removedMissingFitEntries;
  final int restoredFitEntries;
  final int unrestoredFitFiles;
  final int removedMissingBundleEntries;
  final int restoredBundleEntries;
  final bool selectedBundleChanged;

  bool get hasChanges =>
      rewroteFitRegistry ||
      rewroteBundleRegistry ||
      removedMissingFitEntries > 0 ||
      restoredFitEntries > 0 ||
      removedMissingBundleEntries > 0 ||
      restoredBundleEntries > 0 ||
      selectedBundleChanged;

  bool get hasWarnings => unrestoredFitFiles > 0;
  bool get isEmpty => !hasChanges && !hasWarnings;

  StartupPersistenceRepairReport merge(StartupPersistenceRepairReport other) =>
      StartupPersistenceRepairReport(
        rewroteFitRegistry: rewroteFitRegistry || other.rewroteFitRegistry,
        rewroteBundleRegistry: rewroteBundleRegistry || other.rewroteBundleRegistry,
        removedMissingFitEntries: removedMissingFitEntries + other.removedMissingFitEntries,
        restoredFitEntries: restoredFitEntries + other.restoredFitEntries,
        unrestoredFitFiles: unrestoredFitFiles + other.unrestoredFitFiles,
        removedMissingBundleEntries:
            removedMissingBundleEntries + other.removedMissingBundleEntries,
        restoredBundleEntries: restoredBundleEntries + other.restoredBundleEntries,
        selectedBundleChanged: selectedBundleChanged || other.selectedBundleChanged,
      );
}

class StartupPersistenceRepairReporter {
  StartupPersistenceRepairReporter._();

  static final StartupPersistenceRepairReporter instance = StartupPersistenceRepairReporter._();

  StartupPersistenceRepairReport? _report;

  void publish(StartupPersistenceRepairReport report) {
    if (report.isEmpty) {
      return;
    }
    _report = report;
  }

  StartupPersistenceRepairReport? consume() {
    final report = _report;
    _report = null;
    return report;
  }
}

Future<StartupPersistenceRepairReport> repairStartupPersistence() async {
  final report = (await _repairFitPersistence()).merge(await _repairBundlePersistence());
  StartupPersistenceRepairReporter.instance.publish(report);
  return report;
}

Future<StartupPersistenceRepairReport> _repairFitPersistence() async {
  final fittingsDir = Directory(PathProvider.fittingsPath);
  if (!fittingsDir.existsSync()) {
    await fittingsDir.create(recursive: true);
  }

  final registryFile = File(p.join(PathProvider.fittingsPath, "registry.json"));
  var rewroteRegistry = false;
  FitRegistry registry;
  if (!registryFile.existsSync()) {
    registry = FitRegistry(fits: const <String, FitMetadata>{}.lock);
    rewroteRegistry = true;
  } else {
    try {
      final registryJson = jsonDecode(await registryFile.readAsString()) as Map<String, dynamic>;
      final decodedRegistry = decodeFitRegistry(registryJson);
      registry = decodedRegistry.registry;
      rewroteRegistry = decodedRegistry.didMigrate;
    } on Object catch (errorValue, stackTrace) {
      warning(
        "Failed to read fit registry, rebuilding from fit files: $errorValue",
        stackTrace: stackTrace,
      );
      registry = FitRegistry(fits: const <String, FitMetadata>{}.lock);
      rewroteRegistry = true;
    }
  }

  final dynamic registryDynamic = registry;
  final repairedFits = <String, FitMetadata>{
    ...((registryDynamic.fits as IMap<String, FitMetadata>).unlock),
  };
  var removedMissingFitEntries = 0;
  for (final entry in repairedFits.entries.toList()) {
    final fitPath = File(FitStorage.fitStoragePathForId(entry.key));
    if (fitPath.existsSync()) {
      continue;
    }
    removedMissingFitEntries += 1;
    repairedFits.remove(entry.key);
    warning("Removed fit registry entry for missing fit file ${fitPath.path}");
  }

  var restoredFitEntries = 0;
  var unrestoredFitFiles = 0;
  for (final entity in fittingsDir.listSync()) {
    if (entity is! File || p.extension(entity.path) != ".json") {
      continue;
    }
    if (p.basename(entity.path) == "registry.json") {
      continue;
    }

    final fitId = p.basenameWithoutExtension(entity.path);
    if (repairedFits.containsKey(fitId)) {
      continue;
    }

    try {
      final fitJson = jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
      final decodedFit = decodeFitStorage(fitJson);
      final metadata = decodedFit.fit.metadata;
      final dynamic metadataDynamic = metadata;
      final metadataFitId = metadataDynamic.fitId as String;
      if (metadataFitId != fitId) {
        unrestoredFitFiles += 1;
        warning(
          "Skipped orphan fit file with mismatched metadata id ${entity.path}: $metadataFitId",
        );
        continue;
      }
      repairedFits[fitId] = metadata;
      restoredFitEntries += 1;
      if (decodedFit.didMigrate) {
        await entity.writeAsString(jsonEncode(encodeFitStorage(decodedFit.fit)));
      }
      info("Restored missing fit registry entry for $fitId");
    } on Object catch (errorValue, stackTrace) {
      unrestoredFitFiles += 1;
      warning(
        "Failed to restore fit metadata from ${entity.path}: $errorValue",
        stackTrace: stackTrace,
      );
    }
  }

  final repairedRegistry = FitRegistry(fits: repairedFits.lock);
  if (rewroteRegistry || removedMissingFitEntries > 0 || restoredFitEntries > 0) {
    await registryFile.create(recursive: true);
    await registryFile.writeAsString(jsonEncode(encodeFitRegistry(repairedRegistry)));
  }

  return StartupPersistenceRepairReport(
    rewroteFitRegistry: rewroteRegistry,
    rewroteBundleRegistry: false,
    removedMissingFitEntries: removedMissingFitEntries,
    restoredFitEntries: restoredFitEntries,
    unrestoredFitFiles: unrestoredFitFiles,
    removedMissingBundleEntries: 0,
    restoredBundleEntries: 0,
    selectedBundleChanged: false,
  );
}

Future<StartupPersistenceRepairReport> _repairBundlePersistence() async {
  final bundlesDir = Directory(p.join(PathProvider.resourcesPath, "bundles"));
  if (!bundlesDir.existsSync()) {
    await bundlesDir.create(recursive: true);
  }

  final registryFile = File(p.join(PathProvider.resourcesPath, "bundles.json"));
  var rewroteRegistry = false;
  BundleRegistry registry;
  if (!registryFile.existsSync()) {
    registry = const BundleRegistry(bundles: IMap<String, BundleInfo>.empty());
    rewroteRegistry = true;
  } else {
    try {
      final registryJson = jsonDecode(await registryFile.readAsString()) as Map<String, dynamic>;
      registry = BundleRegistry.fromJson(registryJson);
    } on Object catch (errorValue, stackTrace) {
      warning(
        "Failed to read bundle registry, rebuilding from installed bundles: $errorValue",
        stackTrace: stackTrace,
      );
      registry = const BundleRegistry(bundles: IMap<String, BundleInfo>.empty());
      rewroteRegistry = true;
    }
  }

  final installedBundleIds = <String>{
    for (final entity in bundlesDir.listSync())
      if (entity is Directory) p.basename(entity.path),
  };
  final repairedBundles = <String, BundleInfo>{};
  var removedMissingBundleEntries = 0;
  for (final entry in registry.bundles.entries) {
    if (!installedBundleIds.contains(entry.key)) {
      removedMissingBundleEntries += 1;
      warning("Removed bundle registry entry for missing bundle ${entry.key}");
      continue;
    }
    repairedBundles[entry.key] = entry.value;
  }

  var restoredBundleEntries = 0;
  if (rewroteRegistry) {
    for (final bundleId in installedBundleIds) {
      final info = await _readBundleInfo(bundleId);
      if (info == null) {
        continue;
      }
      repairedBundles[bundleId] = info;
      restoredBundleEntries += 1;
    }
  }

  final previousSelectedBundleId = registry.selectedBundleId;
  final selectedBundleId = switch (previousSelectedBundleId) {
    final bundleId? when repairedBundles.containsKey(bundleId) => bundleId,
    _ when repairedBundles.isNotEmpty => repairedBundles.keys.first,
    _ => null,
  };
  final selectedBundleChanged = previousSelectedBundleId != selectedBundleId;
  if (selectedBundleChanged && previousSelectedBundleId != null) {
    warning(
      "Replaced missing selected bundle $previousSelectedBundleId with ${selectedBundleId ?? "no selection"}",
    );
  }

  final repairedRegistry = BundleRegistry(
    bundles: repairedBundles.lock,
    selectedBundleId: selectedBundleId,
  );
  if (rewroteRegistry || removedMissingBundleEntries > 0 || selectedBundleChanged) {
    await registryFile.create(recursive: true);
    await registryFile.writeAsString(
      const JsonEncoder.withIndent("  ").convert(repairedRegistry.toJson()),
    );
  }

  return StartupPersistenceRepairReport(
    rewroteFitRegistry: false,
    rewroteBundleRegistry: rewroteRegistry,
    removedMissingFitEntries: 0,
    restoredFitEntries: 0,
    unrestoredFitFiles: 0,
    removedMissingBundleEntries: removedMissingBundleEntries,
    restoredBundleEntries: restoredBundleEntries,
    selectedBundleChanged: selectedBundleChanged,
  );
}

Future<BundleInfo?> _readBundleInfo(String bundleId) async {
  final descriptorPath = p.join(PathProvider.resourcesPath, "bundles", bundleId, "descriptor.json");
  final descriptorFile = File(descriptorPath);
  if (!descriptorFile.existsSync()) {
    warning("Skipped bundle recovery for $bundleId: missing descriptor.json");
    return null;
  }

  try {
    final json = jsonDecode(await descriptorFile.readAsString());
    if (json is! Map<String, dynamic>) {
      throw const FormatException("Bundle descriptor must be an object.");
    }
    final descriptorBundleId = json["bundleId"];
    final appVersion = json["appVersion"];
    final gameBuild = json["gameBuild"];
    final gameRegion = json["gameRegion"];
    if (descriptorBundleId is! String ||
        appVersion is! String ||
        gameBuild is! String ||
        gameRegion is! String) {
      throw const FormatException("Bundle descriptor is missing required string fields.");
    }
    if (descriptorBundleId != bundleId) {
      throw FormatException(
        "Descriptor bundle id $descriptorBundleId does not match directory $bundleId.",
      );
    }
    return BundleInfo(
      bundleId: descriptorBundleId,
      version: appVersion,
      build: gameBuild,
      region: gameRegion,
    );
  } on Object catch (errorValue, stackTrace) {
    warning("Skipped bundle recovery for $bundleId: $errorValue", stackTrace: stackTrace);
    return null;
  }
}
