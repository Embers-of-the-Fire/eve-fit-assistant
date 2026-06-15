import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:path/path.dart" as p;

class StartupPersistenceRepairReport {
  const StartupPersistenceRepairReport({
    required this.rewroteFitRegistry,
    required this.removedMissingFitEntries,
    required this.restoredFitEntries,
    required this.unrestoredFitFiles,
  });

  const StartupPersistenceRepairReport.empty()
    : rewroteFitRegistry = false,
      removedMissingFitEntries = 0,
      restoredFitEntries = 0,
      unrestoredFitFiles = 0;

  final bool rewroteFitRegistry;
  final int removedMissingFitEntries;
  final int restoredFitEntries;
  final int unrestoredFitFiles;

  bool get hasChanges =>
      rewroteFitRegistry || removedMissingFitEntries > 0 || restoredFitEntries > 0;

  bool get hasWarnings => unrestoredFitFiles > 0;
  bool get isEmpty => !hasChanges && !hasWarnings;

  StartupPersistenceRepairReport merge(StartupPersistenceRepairReport other) =>
      StartupPersistenceRepairReport(
        rewroteFitRegistry: rewroteFitRegistry || other.rewroteFitRegistry,
        removedMissingFitEntries: removedMissingFitEntries + other.removedMissingFitEntries,
        restoredFitEntries: restoredFitEntries + other.restoredFitEntries,
        unrestoredFitFiles: unrestoredFitFiles + other.unrestoredFitFiles,
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

  StartupPersistenceRepairReport? peek() => _report;

  StartupPersistenceRepairReport? consume() {
    final report = _report;
    _report = null;
    return report;
  }
}

Future<StartupPersistenceRepairReport> repairStartupPersistence() async {
  final report = await _runRepairStep("fit persistence", _repairFitPersistence);
  StartupPersistenceRepairReporter.instance.publish(report);
  return report;
}

Future<StartupPersistenceRepairReport> _runRepairStep(
  String stepName,
  Future<StartupPersistenceRepairReport> Function() repairStep,
) async {
  try {
    return await repairStep();
  } on Object catch (errorValue, stackTrace) {
    error(
      "Startup persistence repair failed during $stepName: $errorValue",
      stackTrace: stackTrace,
      error: errorValue,
    );
    return const StartupPersistenceRepairReport.empty();
  }
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

  final repairedFits = <String, FitMetadata>{...registry.fits.unlock};
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
      final metadataFitId = metadata.fitId;
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
    removedMissingFitEntries: removedMissingFitEntries,
    restoredFitEntries: restoredFitEntries,
    unrestoredFitFiles: unrestoredFitFiles,
  );
}
