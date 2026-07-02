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
    tempDir = Directory.systemTemp.createTempSync("efa_migration_test_");
    PathProvider.documentsPath = tempDir.path;
    PathProvider.tempPath = tempDir.path;
    PathProvider.appSupportPath = tempDir.path;
    PathProvider.cachesPath = tempDir.path;
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  Future<void> initAndSync() async {
    AnnouncementStateStore.init();
    await AnnouncementStateStore.ensureSynced;
  }

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
      await initAndSync();

      expect(AnnouncementStateStore.state.schemaVersion, 2);
      expect(AnnouncementStateStore.state.readIds, isEmpty);
      expect(AnnouncementStateStore.state.dismissedIds, isEmpty);
      expect(AnnouncementStateStore.state.lastSeenAppVersion, isNull);
    });

    test("migrates read IDs, dismissed IDs, and lastSeenAppVersion", () async {
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

      await initAndSync();

      expect(AnnouncementStateStore.isRead("announcement-1"), isTrue);
      expect(AnnouncementStateStore.isRead("announcement-2"), isTrue);
      expect(AnnouncementStateStore.isDismissed("startup-1"), isTrue);
      expect(AnnouncementStateStore.isDismissed("startup-2"), isTrue);
      expect(AnnouncementStateStore.lastSeenAppVersion, "2.0.0");
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

      await initAndSync();

      expect(AnnouncementStateStore.isRead("modern-entry"), isTrue);
      expect(AnnouncementStateStore.isRead("legacy-entry"), isFalse);
      expect(AnnouncementStateStore.isDismissed("modern-dismissed"), isTrue);
      expect(AnnouncementStateStore.isDismissed("legacy-dismissed"), isFalse);
      expect(AnnouncementStateStore.lastSeenAppVersion, "3.0.0");
    });

    test("corrupted legacy file falls back to initial", () async {
      legacyFile().writeAsStringSync("not valid json {{{");

      await initAndSync();

      expect(AnnouncementStateStore.state.schemaVersion, 2);
      expect(AnnouncementStateStore.state.readIds, isEmpty);
      expect(AnnouncementStateStore.state.dismissedIds, isEmpty);
    });

    test("post-migration writes announcement_state.json to disk", () async {
      final legacyJson = {
        "version": 3,
        "readTimestamps": {"entry-x": "2026-06-01T00:00:00Z"},
        "dismissedStartupAnnouncementIds": <String>[],
      };
      legacyFile().writeAsStringSync(jsonEncode(legacyJson));

      expect(newStateFile().existsSync(), isFalse);
      await initAndSync();
      expect(newStateFile().existsSync(), isTrue);

      final writtenText = newStateFile().readAsStringSync();
      final writtenJson = jsonDecode(writtenText) as Map<String, dynamic>;
      expect(writtenJson["schemaVersion"], 2);
      expect(writtenJson["readIds"], contains("entry-x"));
    });

    test("post-migration leaves document_storage.json untouched", () async {
      final legacyJson = {
        "version": 3,
        "readTimestamps": {"entry-z": "2026-06-01T00:00:00Z"},
      };
      legacyFile().writeAsStringSync(jsonEncode(legacyJson));

      await initAndSync();

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

      await initAndSync();

      expect(AnnouncementStateStore.state.readIds, isEmpty);
      expect(AnnouncementStateStore.isDismissed("d-1"), isTrue);
      expect(AnnouncementStateStore.lastSeenAppVersion, "4.0.0");
    });

    test("missing dismissedStartupAnnouncementIds produces empty dismissedIds", () async {
      final legacyJson = {
        "version": 3,
        "readTimestamps": {"entry-a": "2026-06-01T00:00:00Z"},
        "lastSeenAppVersion": "5.0.0",
      };
      legacyFile().writeAsStringSync(jsonEncode(legacyJson));

      await initAndSync();

      expect(AnnouncementStateStore.isRead("entry-a"), isTrue);
      expect(AnnouncementStateStore.state.dismissedIds, isEmpty);
      expect(AnnouncementStateStore.lastSeenAppVersion, "5.0.0");
    });
  });
}
