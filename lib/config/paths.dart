import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PathProvider {
  // System provided directories
  static late String documentsPath;
  static late String tempPath;
  static late String appSupportPath;
  static late String? downloadsPath;
  static late String cachesPath;

  static String get resourcesPath => p.join(documentsPath, "resources");
  static String get settingsPath => p.join(documentsPath, "settings");
  static String get logsPath => p.join(documentsPath, "logs");
  static String get cacheResourcesPath => p.join(cachesPath, "resources");

  static Future<void> init() async {
    documentsPath = (await getApplicationDocumentsDirectory()).path;
    tempPath = (await getTemporaryDirectory()).path;
    appSupportPath = (await getApplicationSupportDirectory()).path;
    downloadsPath = (await getDownloadsDirectory())?.path;

    cachesPath = (await getApplicationCacheDirectory()).path;
  }
}
