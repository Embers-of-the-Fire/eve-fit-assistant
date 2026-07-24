import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/remote_content/cache_manager.dart";
import "package:path/path.dart" as p;

/// Wipes all application-local storage and resets the app to first-launch state.
///
/// This is intended for developer/debug use only. After calling [resetAll], the
/// caller should restart the process so that app initialization rebuilds default
/// state and the welcome/setup flow is shown.
class ResetStorageService {
  const ResetStorageService();

  /// Deletes all mutable app data directories and clears in-memory caches.
  ///
  /// Preserves the base documents/support/cache directories themselves; only
  /// the contents owned by the app are removed. Logs are also deleted.
  Future<void> resetAll() async {
    final dirs = <String>[
      PathProvider.settingsPath,
      PathProvider.resourcesPath,
      PathProvider.runtimePath,
      PathProvider.logsPath,
      PathProvider.cacheResourcesPath,
      p.join(PathProvider.tempPath, "efa"),
      // Legacy paths, cleaned up if present.
      PathProvider.oldFittingsPath,
      PathProvider.oldCharactersPath,
      PathProvider.legacySettingsPath,
      PathProvider.legacyResourcesPath,
      PathProvider.legacyRuntimePath,
      PathProvider.legacyLogsPath,
    ];

    for (final path in dirs) {
      await _deleteRecursively(Directory(path));
    }

    await RemoteCache.clear();
  }

  Future<void> _deleteRecursively(Directory dir) async {
    if (!dir.existsSync()) return;
    try {
      await dir.delete(recursive: true);
    } on FileSystemException {
      // Best-effort: some files may be locked. Continue wiping everything else.
    }
  }
}
