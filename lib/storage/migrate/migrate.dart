import 'package:eve_fit_assistant/storage/path.dart';
import 'package:eve_fit_assistant/storage/version.dart';

part 'init.dart';

Future<VersionInfo> executeMigrate(VersionInfo? version) async {
  if (version == null) {
    await initStorage();
    await createVersionFile();
    return VersionInfo.currentVersion;
  }

  if (version.isCompatible()) {
    return version;
  }

  if (version.needsUpgrade()) {
    throw Exception('Upgrade not supported yet');
  }

  if (version.needsMigration()) {
    throw Exception('Migration not supported yet');
  }

  return version;
}
