import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/announcements/state/announcement_state_store.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync("efa_migration_test_");
    PathProvider.documentsPath = tempDir.path;
    PathProvider.tempPath = tempDir.path;
    PathProvider.appSupportPath = tempDir.path;
    PathProvider.cachesPath = tempDir.path;
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  Directory settingsDir() => Directory(p.join(tempDir.path, "settings"));

  File legacyFile() => File(p.join(tempDir.path, "settings", "document_storage.json"));

  File newStateFile() => File(p.join(tempDir.path, "settings", "announcement_state.json"));

  void deleteBothFiles() {
    if (legacyFile().existsSync()) legacyFile().deleteSync();
    if (newStateFile().existsSync()) newStateFile().deleteSync();
  }

  setUp(() {
    deleteBothFiles();
    settingsDir().createSync(recursive: true);
  });

  group("Migration from legacy document_storage.json", () {
    test("fresh install produces initial state", () async {
      final store = AnnouncementStateStore(settingsPath: p.join(tempDir.path, "settings"));
      await store.init();
      await store.ensureSynced;

      expect(store.state.schemaVersion, 3);
      expect(store.state.readIds, isEmpty);
      expect(store.state.dismissedIds, isEmpty);
    });

    test("migrates read IDs and dismissed IDs", () async {
      final legacyJson = {
        "version": 3,
        "readTimestamps": {
          "announcement-1": "2026-06-15T08:00:00Z",
          "announcement-2": "2026-06-16T12:00:00Z",
        },
        "dismissedStartupAnnouncementIds": ["startup-1", "startup-2"],
        "lastSeenAppVersion": "2.0.0",
        "remoteCatalog": {"documents": []},
        "cachedBodies": {},
        "selectedDocumentIds": {},
        "lastDocumentRevision": "abc123",
      };
      legacyFile().writeAsStringSync(jsonEncode(legacyJson));

      final store = AnnouncementStateStore(settingsPath: p.join(tempDir.path, "settings"));
      final migration = await store.init();
      await store.ensureSynced;

      expect(store.isRead("announcement-1"), isTrue);
      expect(store.isRead("announcement-2"), isTrue);
      expect(store.isDismissed("startup-1"), isTrue);
      expect(store.isDismissed("startup-2"), isTrue);
      expect(migration?.lastSeenAppVersion, "2.0.0");
    });

    test("new state file wins over legacy", () async {
      final legacyJson = {
        "version": 3,
        "readTimestamps": {"legacy-entry": "2026-01-01T00:00:00Z"},
        "dismissedStartupAnnouncementIds": ["legacy-dismissed"],
        "lastSeenAppVersion": "1.0.0",
      };
      legacyFile().writeAsStringSync(jsonEncode(legacyJson));

      final newStateJson = {
        "schemaVersion": 1,
        "readIds": ["modern-entry"],
        "dismissedIds": ["modern-dismissed"],
        "lastSeenAppVersion": "3.0.0",
      };
      newStateFile().writeAsStringSync(jsonEncode(newStateJson));

      final store = AnnouncementStateStore(settingsPath: p.join(tempDir.path, "settings"));
      final migration = await store.init();
      await store.ensureSynced;

      expect(store.isRead("modern-entry"), isTrue);
      expect(store.isRead("legacy-entry"), isFalse);
      expect(store.isDismissed("modern-dismissed"), isTrue);
      expect(store.isDismissed("legacy-dismissed"), isFalse);
      expect(migration?.lastSeenAppVersion, "3.0.0");
    });

    test("corrupted legacy file falls back to initial", () async {
      legacyFile().writeAsStringSync("not valid json {{{");

      final store = AnnouncementStateStore(settingsPath: p.join(tempDir.path, "settings"));
      await store.init();
      await store.ensureSynced;

      expect(store.state.schemaVersion, 3);
      expect(store.state.readIds, isEmpty);
      expect(store.state.dismissedIds, isEmpty);
    });

    test("post-migration writes announcement_state.json to disk", () async {
      final legacyJson = {
        "version": 3,
        "readTimestamps": {"entry-x": "2026-06-01T00:00:00Z"},
        "dismissedStartupAnnouncementIds": <String>[],
      };
      legacyFile().writeAsStringSync(jsonEncode(legacyJson));

      expect(newStateFile().existsSync(), isFalse);
      final store = AnnouncementStateStore(settingsPath: p.join(tempDir.path, "settings"));
      await store.init();
      await store.ensureSynced;
      expect(newStateFile().existsSync(), isTrue);

      final writtenText = newStateFile().readAsStringSync();
      final writtenJson = jsonDecode(writtenText) as Map<String, dynamic>;
      expect(writtenJson["schemaVersion"], 3);
      expect(writtenJson["readIds"], contains("entry-x"));
    });

    test("post-migration leaves document_storage.json untouched", () async {
      final legacyJson = {
        "version": 3,
        "readTimestamps": {"entry-z": "2026-06-01T00:00:00Z"},
      };
      legacyFile().writeAsStringSync(jsonEncode(legacyJson));

      final store = AnnouncementStateStore(settingsPath: p.join(tempDir.path, "settings"));
      await store.init();
      await store.ensureSynced;

      expect(legacyFile().existsSync(), isTrue);
      final legacyContent = legacyFile().readAsStringSync();
      expect(legacyContent, jsonEncode(legacyJson));
    });

    test("null or missing readTimestamps produces empty readIds", () async {
      final legacyJson = {
        "version": 3,
        "dismissedStartupAnnouncementIds": ["d-1"],
        "lastSeenAppVersion": "4.0.0",
      };
      legacyFile().writeAsStringSync(jsonEncode(legacyJson));

      final store = AnnouncementStateStore(settingsPath: p.join(tempDir.path, "settings"));
      final migration = await store.init();
      await store.ensureSynced;

      expect(store.state.readIds, isEmpty);
      expect(store.isDismissed("d-1"), isTrue);
      expect(migration?.lastSeenAppVersion, "4.0.0");
    });

    test("missing dismissedStartupAnnouncementIds produces empty dismissedIds", () async {
      final legacyJson = {
        "version": 3,
        "readTimestamps": {"entry-a": "2026-06-01T00:00:00Z"},
        "lastSeenAppVersion": "5.0.0",
      };
      legacyFile().writeAsStringSync(jsonEncode(legacyJson));

      final store = AnnouncementStateStore(settingsPath: p.join(tempDir.path, "settings"));
      final migration = await store.init();
      await store.ensureSynced;

      expect(store.isRead("entry-a"), isTrue);
      expect(store.state.dismissedIds, isEmpty);
      expect(migration?.lastSeenAppVersion, "5.0.0");
    });
  });
}
