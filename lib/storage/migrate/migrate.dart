import 'dart:io';

import 'package:eve_fit_assistant/storage/character/character.dart';
import 'package:eve_fit_assistant/storage/character/character_brief.dart';
import 'package:eve_fit_assistant/storage/character/storage.dart';
import 'package:eve_fit_assistant/storage/fit/storage.dart';
import 'package:eve_fit_assistant/storage/path.dart';
import 'package:eve_fit_assistant/storage/version.dart';
import 'package:eve_fit_assistant/widgets/loading.dart';

part 'init.dart';
part 'migrate_1_to_2.dart';

const String _migrateLoadingKey = 'migrate';

Future<VersionInfo> executeMigrate(VersionInfo? version) async {
  GlobalLoading().add(_migrateLoadingKey, '迁移旧版数据');
  if (version == null) {
    await initStorage();
    await createVersionFile();
    return VersionInfo.currentVersion;
  }

  if (version.needsUpgrade()) {
    throw Exception('Upgrade not supported yet');
  }

  if (version.needsMigration()) {
    await initStorage();
    for (var i = version.version; i < VersionInfo.currentVersion.version; i++) {
      await _migrations[i]!();
    }
    await createVersionFile();
    return VersionInfo.currentVersion;
  }

  GlobalLoading().dismiss(_migrateLoadingKey);

  return version;
}

final Map<int, Future<void> Function()> _migrations = {
  1: migrate1To2,
};
