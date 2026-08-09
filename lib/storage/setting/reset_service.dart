import "package:eve_fit_assistant/compat/io.dart";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/storage_root.dart";
import "package:eve_fit_assistant/features/remote_content/cache_manager.dart";
import "package:eve_fit_assistant/storage/fs/doc_store.dart";
import "package:eve_fit_assistant/storage/fs/repo_store.dart";
import "package:eve_fit_assistant/storage/fs/user_store.dart";
import "package:eve_fit_assistant/storage/repo/localization_db_web.dart"
    if (dart.library.io) "package:eve_fit_assistant/storage/repo/localization_db_web_stub.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:flutter/foundation.dart";
import "package:path/path.dart" as p;

/// Wipes all application-local storage and resets the app to first-launch state.
///
/// This is intended for developer/debug use only. After calling [resetAll], the
/// caller should restart the process so that app initialization rebuilds default
/// state and the welcome/setup flow is shown.
class ResetStorageService {
  const ResetStorageService();

  /// Deletes all mutable app data and clears in-memory caches.
  ///
  /// On native this removes the app-owned directory contents (preserving the
  /// base directories themselves). On web it clears the OPFS repo tree and the
  /// IndexedDB-backed user document stores.
  Future<void> resetAll() async {
    if (kIsWeb) {
      await _resetWeb();
    } else {
      await _resetNative();
    }
    await RemoteCache.clear();
  }

  Future<void> _resetNative() async {
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

    // Drop the storage-root preference so the next launch boots from the
    // platform-default directory again.
    await StorageRootPreference.write(null);
  }

  Future<void> _resetWeb() async {
    // Wipe the OPFS copies of the localization database. This waits for any
    // in-flight close so the worker has released its SyncAccessHandles first;
    // callers are expected to close the localization service before reset.
    await deleteWebLocalizationDatabases();

    // Wipe the repo tree (blobs, snapshots, channels, checkouts). The
    // schema_version.json marker never exists on web (the migration gate is
    // skipped there), so it is not part of the wipe.
    final repoStore = createRepoBlobStore();
    await repoStore.init();
    for (final path in [RepoPaths.assetsPath, RepoPaths.channelsPath, RepoPaths.checkoutsPath]) {
      await repoStore.deleteTree(path);
    }

    // Wipe the user document stores (fits, characters, settings).
    for (final domain in UserDataDomain.values) {
      final docs = createUserDocStore(domain);
      await docs.init();
      for (final key in await docs.keys()) {
        await docs.delete(key);
      }
    }
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
