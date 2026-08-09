import "package:eve_fit_assistant/compat/io.dart";

import "package:flutter/foundation.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

const applicationId = "dev.efa_tech.eve_fit_assistant";

class PathProvider {
  const PathProvider._();
  // System provided directories
  static late String documentsPath;
  static late String tempPath;

  /// The effective application-support directory. Equal to
  /// [defaultAppSupportPath] unless a user-configured storage root was applied
  /// via [applyStorageRootOverride].
  static late String appSupportPath;

  /// The platform-provided application-support directory. Never rebased, so
  /// bootstrap data that must be found before the storage-root override
  /// applies (e.g. the storage-root preference itself) anchors here.
  static late String defaultAppSupportPath;
  static late String? downloadsPath;
  static late String cachesPath;

  static String get resourcesPath => p.join(appSupportPath, "resources");
  static String get settingsPath => p.join(appSupportPath, "settings");

  static String get oldFittingsPath => p.join(documentsPath, "fittings");
  static String get oldCharactersPath => p.join(documentsPath, "characters");

  static String get runtimePath => p.join(appSupportPath, "runtime", "v2");
  static String get fittingsPath => p.join(runtimePath, "fittings");
  static String get charactersPath => p.join(runtimePath, "characters");
  static String get chatPath => p.join(runtimePath, "chat");

  static String get logsPath => p.join(appSupportPath, "logs");
  static String get cacheResourcesPath => p.join(cachesPath, "resources");

  static String get legacyResourcesPath => p.join(documentsPath, "resources");
  static String get legacySettingsPath => p.join(documentsPath, "settings");
  static String get legacyRuntimePath => p.join(documentsPath, "runtime");
  static String get legacyLogsPath => p.join(documentsPath, "logs");
  static Future<void> init() async {
    if (kIsWeb) {
      // Web has no filesystem and path_provider has no web implementation.
      // Placeholder paths keep legacy path-derived constants well-defined;
      // real persistence goes through the OPFS/IndexedDB stores in
      // `lib/storage/fs/`.
      documentsPath = tempPath = appSupportPath = defaultAppSupportPath = cachesPath = "/";
      downloadsPath = null;
      return;
    }
    documentsPath = (await getApplicationDocumentsDirectory()).path;
    tempPath = (await getTemporaryDirectory()).path;
    appSupportPath = (await getApplicationSupportDirectory()).path;
    downloadsPath = (await getDownloadsDirectory())?.path;
    cachesPath = (await getApplicationCacheDirectory()).path;

    if (Platform.isLinux) {
      // xdg-user-dir may fail silently under AppImage runtimes (empty path);
      // fall back to $HOME/Documents to avoid a relative path leaking into CWD.
      if (documentsPath.isEmpty) {
        documentsPath = p.join(Platform.environment["HOME"] ?? ".", "Documents");
      }
      documentsPath = p.join(documentsPath, applicationId);
      appSupportPath = p.join(p.dirname(appSupportPath), applicationId);
      cachesPath = p.join(p.dirname(cachesPath), applicationId);
    }
    defaultAppSupportPath = appSupportPath;
  }

  /// Rebases the effective application-support directory (and every storage
  /// path derived from it) onto a user-configured storage root. Blank or null
  /// keeps the platform default. Must run immediately after [init], before
  /// any store opens; spawned isolates receive the rebased value through the
  /// captured-paths seeding in `lib/storage/repo/verification.dart`.
  static void applyStorageRootOverride(String? root) {
    if (kIsWeb) return;
    final trimmed = root?.trim() ?? "";
    if (trimmed.isEmpty) return;
    appSupportPath = trimmed;
  }
}
