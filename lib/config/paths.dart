import "dart:io";

import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

const applicationId = "dev.efa_tech.eve_fit_assistant";

class PathProvider {
  const PathProvider._();
  // System provided directories
  static late String documentsPath;
  static late String tempPath;
  static late String appSupportPath;
  static late String? downloadsPath;
  static late String cachesPath;

  static String get resourcesPath => p.join(appSupportPath, "resources");
  static String get settingsPath => p.join(appSupportPath, "settings");

  static String get oldFittingsPath => p.join(documentsPath, "fittings");
  static String get oldCharactersPath => p.join(documentsPath, "characters");

  static String get runtimePath => p.join(appSupportPath, "runtime", "v2");
  static String get fittingsPath => p.join(runtimePath, "fittings");
  static String get charactersPath => p.join(runtimePath, "characters");

  static String get logsPath => p.join(appSupportPath, "logs");
  static String get cacheResourcesPath => p.join(cachesPath, "resources");

  static String get legacyResourcesPath => p.join(documentsPath, "resources");
  static String get legacySettingsPath => p.join(documentsPath, "settings");
  static String get legacyRuntimePath => p.join(documentsPath, "runtime");
  static String get legacyLogsPath => p.join(documentsPath, "logs");
  static Future<void> init() async {
    documentsPath = (await getApplicationDocumentsDirectory()).path;
    tempPath = (await getTemporaryDirectory()).path;
    appSupportPath = (await getApplicationSupportDirectory()).path;
    downloadsPath = (await getDownloadsDirectory())?.path;
    cachesPath = (await getApplicationCacheDirectory()).path;

    if (Platform.isLinux) {
      documentsPath = p.join(documentsPath, applicationId);
      appSupportPath = p.join(p.dirname(appSupportPath), applicationId);
      cachesPath = p.join(p.dirname(cachesPath), applicationId);
    }
  }
}
