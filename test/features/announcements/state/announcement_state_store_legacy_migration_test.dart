@TestOn("vm")
library;

import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/announcements/state/announcement_state_store.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

// Regression test for first-ever init() with a legacy document_storage.json.
void main() {
  test("legacy document_storage.json migrates on first-ever init", () async {
    final tempDir = Directory.systemTemp.createTempSync("efa_legacy_migration_test_");
    addTearDown(() => tempDir.deleteSync(recursive: true));

    PathProvider.documentsPath = tempDir.path;
    PathProvider.tempPath = tempDir.path;
    PathProvider.appSupportPath = tempDir.path;
    PathProvider.cachesPath = tempDir.path;

    final settingsDir = Directory(p.join(tempDir.path, "settings"))..createSync(recursive: true);
    File(p.join(settingsDir.path, "document_storage.json")).writeAsStringSync(
      jsonEncode({
        "readTimestamps": {"legacy-read-1": 1, "legacy-read-2": 2},
        "dismissedStartupAnnouncementIds": ["legacy-dismissed-1"],
        "lastSeenAppVersion": "1.2.3",
      }),
    );

    final store = AnnouncementStateStore(settingsPath: p.join(tempDir.path, "settings"));
    final migration = await store.init();
    await store.ensureSynced;

    expect(store.state.readIds, containsAll(["legacy-read-1", "legacy-read-2"]));
    expect(store.state.dismissedIds, ["legacy-dismissed-1"]);
    expect(store.state.schemaVersion, 3);

    // The migration data should carry lastSeenAppVersion for the caller to
    // apply to AppVersionStateStore.
    expect(migration, isNotNull);
    expect(migration!.lastSeenAppVersion, "1.2.3");
    expect(migration.lastAcknowledgedReleaseId, isNull);

    final migratedFile = File(p.join(settingsDir.path, "announcement_state.json"));
    expect(migratedFile.existsSync(), isTrue);

    final migratedJson = jsonDecode(migratedFile.readAsStringSync()) as Map<String, dynamic>;
    expect(migratedJson["schemaVersion"], 3);
    expect(migratedJson["readIds"], containsAll(["legacy-read-1", "legacy-read-2"]));
    expect(migratedJson["dismissedIds"], ["legacy-dismissed-1"]);
    expect(migratedJson.containsKey("lastSeenAppVersion"), isFalse);
    expect(migratedJson.containsKey("lastAcknowledgedReleaseId"), isFalse);
  });
}
