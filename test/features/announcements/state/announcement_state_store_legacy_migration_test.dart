import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/announcements/state/announcement_state_store.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

// Regression test for first-ever init() with a legacy document_storage.json.
// This must live in its own file because AnnouncementStateStore uses static
// late state; earlier init() calls in other tests would mask the bug.
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

    AnnouncementStateStore.init();
    await AnnouncementStateStore.ensureSynced;

    expect(AnnouncementStateStore.state.readIds, containsAll(["legacy-read-1", "legacy-read-2"]));
    expect(AnnouncementStateStore.state.dismissedIds, ["legacy-dismissed-1"]);
    expect(AnnouncementStateStore.state.lastSeenAppVersion, "1.2.3");
    expect(AnnouncementStateStore.state.lastAcknowledgedReleaseId, isNull);
    expect(AnnouncementStateStore.state.schemaVersion, 2);

    final migratedFile = File(p.join(settingsDir.path, "announcement_state.json"));
    expect(migratedFile.existsSync(), isTrue);

    final migratedJson = jsonDecode(migratedFile.readAsStringSync()) as Map<String, dynamic>;
    expect(migratedJson["schemaVersion"], 2);
    expect(migratedJson["readIds"], containsAll(["legacy-read-1", "legacy-read-2"]));
    expect(migratedJson["dismissedIds"], ["legacy-dismissed-1"]);
    expect(migratedJson["lastSeenAppVersion"], "1.2.3");
    expect(migratedJson["lastAcknowledgedReleaseId"], isNull);
  });
}
