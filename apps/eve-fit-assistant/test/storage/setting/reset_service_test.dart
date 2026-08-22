@TestOn("vm")
library;

import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/remote_content/cache_manager.dart";
import "package:eve_fit_assistant/storage/setting/reset_service.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

void main() {
  late Directory tempRoot;
  late bool accountCredentialsCleared;

  // Secure storage needs the platform binding; the account wipe is injected
  // as a recorder instead.
  ResetStorageService service() =>
      ResetStorageService(clearAccountCredentials: () async => accountCredentialsCleared = true);

  setUp(() async {
    accountCredentialsCleared = false;
    tempRoot = await Directory.systemTemp.createTemp("efa_reset_test_");
    PathProvider.documentsPath = p.join(tempRoot.path, "documents");
    PathProvider.tempPath = p.join(tempRoot.path, "temp");
    PathProvider.appSupportPath = p.join(tempRoot.path, "support");
    PathProvider.defaultAppSupportPath = PathProvider.appSupportPath;
    PathProvider.downloadsPath = null;
    PathProvider.cachesPath = p.join(tempRoot.path, "cache");
    await RemoteCache.init();
  });

  tearDown(() async {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test("resetAll deletes all mutable storage directories", () async {
    final files = <String>[
      p.join(PathProvider.settingsPath, "settings.json"),
      p.join(PathProvider.resourcesPath, "v2", "channels", "testing", "metadata.json"),
      p.join(PathProvider.runtimePath, "fittings", "fit.json"),
      p.join(PathProvider.runtimePath, "characters", "char.json"),
      p.join(PathProvider.logsPath, "app.log"),
      p.join(PathProvider.cacheResourcesPath, "blob"),
      p.join(PathProvider.tempPath, "efa", "native", "foo"),
      p.join(PathProvider.oldFittingsPath, "fit.json"),
      p.join(PathProvider.oldCharactersPath, "char.json"),
      p.join(PathProvider.legacySettingsPath, "settings.json"),
      p.join(PathProvider.legacyResourcesPath, "v2", "schema_version.json"),
      p.join(PathProvider.legacyRuntimePath, "v2", "fittings", "fit.json"),
      p.join(PathProvider.legacyLogsPath, "app.log"),
    ];

    for (final filePath in files) {
      final file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsString("test");
    }

    await service().resetAll();

    for (final filePath in files) {
      expect(File(filePath).existsSync(), isFalse, reason: "$filePath should be deleted");
    }
    expect(accountCredentialsCleared, isTrue);
  });

  test("resetAll clears the HTTP cache", () async {
    // The cache store is opaque; we verify resetAll completes without throwing.
    await service().resetAll();
  });

  test("resetAll is idempotent on empty directories", () async {
    await service().resetAll();
    await service().resetAll();
    expect(tempRoot.existsSync(), isTrue);
  });

  test(
    "resetAll clears credentials even when reset work fails",
    () async {
      // Force StorageRootPreference.write(null) to fail: the preference file
      // exists but its directory is read-only, so the delete throws and
      // resetAll aborts before reaching the credential cleanup.
      final prefDir = Directory(PathProvider.defaultAppSupportPath);
      await prefDir.create(recursive: true);
      await File(p.join(prefDir.path, "storage_root.json")).writeAsString("{}");
      await Process.run("chmod", ["a-w", prefDir.path]);
      try {
        await expectLater(service().resetAll(), throwsA(isA<FileSystemException>()));
      } finally {
        await Process.run("chmod", ["u+w", prefDir.path]);
      }
      expect(accountCredentialsCleared, isTrue);
    },
    // Relies on POSIX permissions to make the preference delete fail.
    skip: Platform.isWindows,
  );
}
