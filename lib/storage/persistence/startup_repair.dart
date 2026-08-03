import "dart:convert";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/fs/doc_store.dart";
import "package:eve_fit_assistant/storage/fs/user_store.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";

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
  final store = createUserDocStore(UserDataDomain.fittings);
  await store.init();

  var rewroteRegistry = false;
  FitRegistry registry;
  final registryText = await store.read("registry.json");
  if (registryText == null) {
    registry = FitRegistry(fits: const <String, FitMetadata>{}.lock);
    rewroteRegistry = true;
  } else {
    try {
      final decodedRegistry = decodeFitRegistry(jsonDecode(registryText) as Map<String, dynamic>);
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
    if (await store.exists("${entry.key}.json")) {
      continue;
    }
    removedMissingFitEntries += 1;
    repairedFits.remove(entry.key);
    warning("Removed fit registry entry for missing fit file ${entry.key}");
  }

  var restoredFitEntries = 0;
  var unrestoredFitFiles = 0;
  for (final key in await store.keys()) {
    if (!key.endsWith(".json")) {
      continue;
    }
    if (key == "registry.json") {
      continue;
    }

    final fitId = key.substring(0, key.length - ".json".length);
    if (repairedFits.containsKey(fitId)) {
      continue;
    }

    try {
      final text = await store.read(key);
      if (text == null) {
        unrestoredFitFiles += 1;
        continue;
      }
      final decodedFit = decodeFitStorage(jsonDecode(text) as Map<String, dynamic>);
      final metadata = decodedFit.fit.metadata;
      final metadataFitId = metadata.fitId;
      if (metadataFitId != fitId) {
        unrestoredFitFiles += 1;
        warning("Skipped orphan fit file with mismatched metadata id $key: $metadataFitId");
        continue;
      }
      repairedFits[fitId] = metadata;
      restoredFitEntries += 1;
      if (decodedFit.didMigrate) {
        await store.write(key, jsonEncode(encodeFitStorage(decodedFit.fit)));
      }
      info("Restored missing fit registry entry for $fitId");
    } on Object catch (errorValue, stackTrace) {
      unrestoredFitFiles += 1;
      warning("Failed to restore fit metadata from $key: $errorValue", stackTrace: stackTrace);
    }
  }

  final repairedRegistry = FitRegistry(fits: repairedFits.lock);
  if (rewroteRegistry || removedMissingFitEntries > 0 || restoredFitEntries > 0) {
    await store.write("registry.json", jsonEncode(encodeFitRegistry(repairedRegistry)));
  }

  return StartupPersistenceRepairReport(
    rewroteFitRegistry: rewroteRegistry,
    removedMissingFitEntries: removedMissingFitEntries,
    restoredFitEntries: restoredFitEntries,
    unrestoredFitFiles: unrestoredFitFiles,
  );
}
