import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/announcements/models/announcement_state.dart";
import "package:eve_fit_assistant/features/announcements/state/announcement_state_store.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync("efa_state_store_test_");
    PathProvider.documentsPath = tempDir.path;
    PathProvider.tempPath = tempDir.path;
    PathProvider.appSupportPath = tempDir.path;
    PathProvider.cachesPath = tempDir.path;
  });

  setUp(() async {
    final file = File(p.join(tempDir.path, "settings", "announcement_state.json"));
    if (file.existsSync()) file.deleteSync();
    AnnouncementStateStore.init();
    await AnnouncementStateStore.ensureSynced;
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  group("AnnouncementStateStore", () {
    test("init produces initial state on first run", () {
      expect(AnnouncementStateStore.state.schemaVersion, 1);
      expect(AnnouncementStateStore.state.readIds, isEmpty);
      expect(AnnouncementStateStore.state.dismissedIds, isEmpty);
      expect(AnnouncementStateStore.state.lastSeenAppVersion, isNull);
    });

    test("read/write round-trip", () async {
      AnnouncementStateStore.markRead("entry-1");
      AnnouncementStateStore.dismiss("entry-2");
      AnnouncementStateStore.setLastSeenAppVersion("2.0.0");

      await AnnouncementStateStore.ensureSynced;

      AnnouncementStateStore.init();

      expect(AnnouncementStateStore.isRead("entry-1"), isTrue);
      expect(AnnouncementStateStore.isDismissed("entry-2"), isTrue);
      expect(AnnouncementStateStore.lastSeenAppVersion, "2.0.0");
    });

    test("markRead is idempotent", () {
      AnnouncementStateStore.markRead("entry-1");
      final first = AnnouncementStateStore.state.readIds.length;
      AnnouncementStateStore.markRead("entry-1");
      expect(AnnouncementStateStore.state.readIds.length, first);
      expect(AnnouncementStateStore.isRead("entry-1"), isTrue);
    });

    test("markAllRead with partial overlap", () {
      AnnouncementStateStore.markRead("entry-1");
      AnnouncementStateStore.markAllRead(["entry-1", "entry-2", "entry-3"]);
      expect(AnnouncementStateStore.isRead("entry-1"), isTrue);
      expect(AnnouncementStateStore.isRead("entry-2"), isTrue);
      expect(AnnouncementStateStore.isRead("entry-3"), isTrue);
      expect(AnnouncementStateStore.state.readIds.length, 3);
    });

    test("markUnread removes ids", () {
      AnnouncementStateStore.markRead("entry-1");
      AnnouncementStateStore.markRead("entry-2");
      AnnouncementStateStore.markRead("entry-3");

      AnnouncementStateStore.markUnread(["entry-1", "entry-3"]);

      expect(AnnouncementStateStore.isRead("entry-1"), isFalse);
      expect(AnnouncementStateStore.isRead("entry-2"), isTrue);
      expect(AnnouncementStateStore.isRead("entry-3"), isFalse);
    });

    test("markUnread is idempotent", () {
      AnnouncementStateStore.markRead("entry-1");
      final first = AnnouncementStateStore.state.readIds.length;
      AnnouncementStateStore.markUnread(["entry-2"]);
      expect(AnnouncementStateStore.state.readIds.length, first);
    });

    test("dismiss is idempotent", () {
      AnnouncementStateStore.dismiss("entry-1");
      final first = AnnouncementStateStore.state.dismissedIds.length;
      AnnouncementStateStore.dismiss("entry-1");
      expect(AnnouncementStateStore.state.dismissedIds.length, first);
      expect(AnnouncementStateStore.isDismissed("entry-1"), isTrue);
    });

    test("setLastSeenAppVersion persists", () async {
      AnnouncementStateStore.setLastSeenAppVersion("3.0.0");
      expect(AnnouncementStateStore.lastSeenAppVersion, "3.0.0");

      await AnnouncementStateStore.ensureSynced;
      AnnouncementStateStore.init();

      expect(AnnouncementStateStore.lastSeenAppVersion, "3.0.0");
    });

    test("setLastSeenAppVersion is idempotent", () {
      AnnouncementStateStore.setLastSeenAppVersion("2.0.0");
      final first = AnnouncementStateStore.state.lastSeenAppVersion;
      AnnouncementStateStore.setLastSeenAppVersion("2.0.0");
      expect(AnnouncementStateStore.state.lastSeenAppVersion, first);
    });

    test("schema version migration", () async {
      final oldJson = jsonEncode({
        "schemaVersion": 0,
        "readIds": ["old-entry"],
        "dismissedIds": [],
        "lastSeenAppVersion": null,
      });
      final settingsDir = Directory(p.join(tempDir.path, "settings"));
      settingsDir.createSync(recursive: true);
      File(p.join(settingsDir.path, "announcement_state.json")).writeAsStringSync(oldJson);

      AnnouncementStateStore.init();

      expect(AnnouncementStateStore.state.schemaVersion, 1);
      expect(AnnouncementStateStore.isRead("old-entry"), isTrue);
    });

    test("corrupt file falls back to initial", () {
      final settingsDir = Directory(p.join(tempDir.path, "settings"));
      settingsDir.createSync(recursive: true);
      File(p.join(settingsDir.path, "announcement_state.json")).writeAsStringSync("not json");

      AnnouncementStateStore.init();

      expect(AnnouncementStateStore.state.schemaVersion, 1);
      expect(AnnouncementStateStore.state.readIds, isEmpty);
    });

    test("replaceState replaces entire state", () {
      AnnouncementStateStore.markRead("entry-1");
      AnnouncementStateStore.dismiss("entry-2");

      AnnouncementStateStore.replaceState(
        AnnouncementState(
          readIds: ["migrated-1", "migrated-2"],
          dismissedIds: ["migrated-3"],
          lastSeenAppVersion: "4.0.0",
        ),
      );

      expect(AnnouncementStateStore.isRead("entry-1"), isFalse);
      expect(AnnouncementStateStore.isRead("migrated-1"), isTrue);
      expect(AnnouncementStateStore.isDismissed("migrated-3"), isTrue);
      expect(AnnouncementStateStore.lastSeenAppVersion, "4.0.0");
    });

    test("isRead returns false for unknown id", () {
      expect(AnnouncementStateStore.isRead("nonexistent"), isFalse);
    });

    test("isDismissed returns false for unknown id", () {
      expect(AnnouncementStateStore.isDismissed("nonexistent"), isFalse);
    });
  });
}
