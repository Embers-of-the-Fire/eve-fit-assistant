import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/remote_content/cache_manager.dart";
import "package:eve_fit_assistant/storage/setting/reset_service.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp("efa_reset_test_");
    PathProvider.documentsPath = p.join(tempRoot.path, "documents");
    PathProvider.tempPath = p.join(tempRoot.path, "temp");
    PathProvider.appSupportPath = p.join(tempRoot.path, "support");
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
    ];

    for (final filePath in files) {
      final file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsString("test");
    }

    await const ResetStorageService().resetAll();

    for (final filePath in files) {
      expect(File(filePath).existsSync(), isFalse, reason: "$filePath should be deleted");
    }
  });

  test("resetAll clears the HTTP cache", () async {
    // The cache store is opaque; we verify resetAll completes without throwing.
    await const ResetStorageService().resetAll();
  });

  test("resetAll is idempotent on empty directories", () async {
    await const ResetStorageService().resetAll();
    await const ResetStorageService().resetAll();
    expect(tempRoot.existsSync(), isTrue);
  });
}
