@TestOn("vm")
library;

import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/announcements/models/announcement_state.dart";
import "package:eve_fit_assistant/features/announcements/state/announcement_state_store.dart";
import "package:eve_fit_assistant/storage/fs/file_doc_store.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

void main() {
  late AnnouncementStateStore store;
  late String settingsPath;

  setUp(() async {
    final testDir = Directory.systemTemp.createTempSync("efa_state_store_test_");
    // Do not delete in tearDown — Isolate.run writes may still be in flight
    // when the test completes, causing "Directory not empty" errors. The OS
    // will reclaim /tmp files.
    PathProvider.documentsPath = testDir.path;
    PathProvider.tempPath = testDir.path;
    PathProvider.appSupportPath = testDir.path;
    PathProvider.cachesPath = testDir.path;
    settingsPath = p.join(testDir.path, "settings");
    store = AnnouncementStateStore(store: FileDocStore(settingsPath));
    await store.init();
    await store.ensureSynced;
  });

  group("AnnouncementStateStore", () {
    test("init produces initial state on first run", () {
      expect(store.state.schemaVersion, 3);
      expect(store.state.readIds, isEmpty);
      expect(store.state.dismissedIds, isEmpty);
    });

    test("read/write round-trip", () async {
      store.markRead("entry-1");
      store.dismiss("entry-2");

      await store.ensureSynced;

      final reloaded = AnnouncementStateStore(store: FileDocStore(settingsPath));
      await reloaded.init();

      expect(reloaded.isRead("entry-1"), isTrue);
      expect(reloaded.isDismissed("entry-2"), isTrue);
    });

    test("markRead is idempotent", () {
      store.markRead("entry-1");
      final first = store.state.readIds.length;
      store.markRead("entry-1");
      expect(store.state.readIds.length, first);
      expect(store.isRead("entry-1"), isTrue);
    });

    test("markAllRead with partial overlap", () {
      store.markRead("entry-1");
      store.markAllRead(["entry-1", "entry-2", "entry-3"]);
      expect(store.isRead("entry-1"), isTrue);
      expect(store.isRead("entry-2"), isTrue);
      expect(store.isRead("entry-3"), isTrue);
      expect(store.state.readIds.length, 3);
    });

    test("markUnread removes ids", () {
      store.markRead("entry-1");
      store.markRead("entry-2");
      store.markRead("entry-3");

      store.markUnread(["entry-1", "entry-3"]);

      expect(store.isRead("entry-1"), isFalse);
      expect(store.isRead("entry-2"), isTrue);
      expect(store.isRead("entry-3"), isFalse);
    });

    test("markUnread is idempotent", () {
      store.markRead("entry-1");
      final first = store.state.readIds.length;
      store.markUnread(["entry-2"]);
      expect(store.state.readIds.length, first);
    });

    test("dismiss is idempotent", () {
      store.dismiss("entry-1");
      final first = store.state.dismissedIds.length;
      store.dismiss("entry-1");
      expect(store.state.dismissedIds.length, first);
      expect(store.isDismissed("entry-1"), isTrue);
    });

    test("schema version migration", () async {
      final oldJson = jsonEncode({
        "schemaVersion": 0,
        "readIds": ["old-entry"],
        "dismissedIds": [],
      });
      final settingsDir = Directory(settingsPath);
      settingsDir.createSync(recursive: true);
      File(p.join(settingsDir.path, "announcement_state.json")).writeAsStringSync(oldJson);

      final reloaded = AnnouncementStateStore(store: FileDocStore(settingsPath));
      await reloaded.init();

      expect(reloaded.state.schemaVersion, 3);
      expect(reloaded.isRead("old-entry"), isTrue);
    });

    test("corrupt file falls back to initial", () async {
      final settingsDir = Directory(settingsPath);
      settingsDir.createSync(recursive: true);
      File(p.join(settingsDir.path, "announcement_state.json")).writeAsStringSync("not json");

      final reloaded = AnnouncementStateStore(store: FileDocStore(settingsPath));
      await reloaded.init();

      expect(reloaded.state.schemaVersion, 3);
      expect(reloaded.state.readIds, isEmpty);
    });

    test("replaceState replaces entire state", () {
      store.markRead("entry-1");
      store.dismiss("entry-2");

      store.replaceState(
        AnnouncementState(readIds: ["migrated-1", "migrated-2"], dismissedIds: ["migrated-3"]),
      );

      expect(store.isRead("entry-1"), isFalse);
      expect(store.isRead("migrated-1"), isTrue);
      expect(store.isDismissed("migrated-3"), isTrue);
    });

    test("isRead returns false for unknown id", () {
      expect(store.isRead("nonexistent"), isFalse);
    });

    test("isDismissed returns false for unknown id", () {
      expect(store.isDismissed("nonexistent"), isFalse);
    });

    test("pruneStaleIds removes ids not in active set", () {
      store.markRead("entry-1");
      store.markRead("entry-2");
      store.markRead("entry-3");
      store.dismiss("entry-4");

      store.pruneStaleIds(activeIds: {"entry-1", "entry-4"});

      expect(store.isRead("entry-1"), isTrue);
      expect(store.isRead("entry-2"), isFalse);
      expect(store.isRead("entry-3"), isFalse);
      expect(store.isDismissed("entry-4"), isTrue);
    });

    test("pruneStaleIds is a no-op when nothing is stale", () {
      store.markRead("entry-1");
      store.pruneStaleIds(activeIds: {"entry-1"});
      expect(store.state.readIds, ["entry-1"]);
    });
  });
}
