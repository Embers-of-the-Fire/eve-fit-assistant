import "dart:convert";

import "package:eve_fit_assistant/features/announcements/models/announcement_catalog.dart";
import "package:eve_fit_assistant/features/announcements/models/announcement_entry.dart";
import "package:eve_fit_assistant/features/announcements/models/announcement_page.dart";
import "package:eve_fit_assistant/features/announcements/models/announcement_platform.dart";
import "package:eve_fit_assistant/features/announcements/models/announcement_record.dart";
import "package:eve_fit_assistant/features/announcements/models/announcement_state.dart";
import "package:eve_fit_assistant/features/announcements/models/localization_meta.dart";
import "package:eve_fit_assistant/features/announcements/models/page_summary.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("Comprehensive JSON round-trip", () {
    test("LocalizationMeta round-trip", () {
      final meta = LocalizationMeta(
        title: "Test Title",
        summary: "Test Summary",
        bodyHash: "abc123def456",
      );
      final restored = LocalizationMeta.fromJson(
        jsonDecode(jsonEncode(meta.toJson())) as Map<String, dynamic>,
      );
      expect(restored, meta);
    });

    test("PageSummary round-trip with defaults", () {
      final summary = PageSummary(
        uuid: "test-uuid",
        publishedAt: DateTime.utc(2026, 1, 1),
        minAppVersion: "1.0.0",
      );
      final restored = PageSummary.fromJson(
        jsonDecode(jsonEncode(summary.toJson())) as Map<String, dynamic>,
      );
      expect(restored, summary);
      expect(restored.channels, isEmpty);
      expect(restored.count, 0);
      expect(restored.active, isFalse);
    });

    test("PageSummary round-trip full", () {
      final summary = PageSummary(
        uuid: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
        publishedAt: DateTime.utc(2026, 6, 15),
        minAppVersion: "2.0.0",
        channels: ["stable", "beta"],
        count: 30,
        active: false,
      );
      final restored = PageSummary.fromJson(
        jsonDecode(jsonEncode(summary.toJson())) as Map<String, dynamic>,
      );
      expect(restored, summary);
      expect(restored.channels, ["stable", "beta"]);
      expect(restored.count, 30);
      expect(restored.active, isFalse);
    });

    test("AnnouncementEntry round-trip with defaults", () {
      final entry = AnnouncementEntry(
        id: "test-entry",
        publishedAt: DateTime.utc(2026, 1, 1),
        channels: ["stable"],
        platforms: [AnnouncementPlatform.android],
        localizations: {
          "en": LocalizationMeta(title: "Title", summary: "Summary", bodyHash: "hash"),
        },
      );
      final restored = AnnouncementEntry.fromJson(
        jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>,
      );
      expect(restored, entry);
      expect(restored.tags, isEmpty);
      expect(restored.startup, isFalse);
      expect(restored.minAppVersion, isNull);
      expect(restored.maxAppVersion, isNull);
    });

    test("AnnouncementEntry round-trip full", () {
      final entry = AnnouncementEntry(
        id: "full-entry",
        publishedAt: DateTime.utc(2026, 6, 15, 8),
        tags: ["maintenance", "downtime"],
        startup: true,
        minAppVersion: "1.5.0",
        maxAppVersion: "2.9.0",
        channels: ["stable", "beta"],
        platforms: [AnnouncementPlatform.android, AnnouncementPlatform.ios],
        appVersion: "2.0.0",
        localizations: {
          "en": LocalizationMeta(title: "English", summary: "Summary", bodyHash: "en_hash"),
          "zh": LocalizationMeta(title: "中文", summary: "摘要", bodyHash: "zh_hash"),
        },
      );
      final restored = AnnouncementEntry.fromJson(
        jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>,
      );
      expect(restored, entry);
      expect(restored.tags, ["maintenance", "downtime"]);
      expect(restored.minAppVersion, "1.5.0");
      expect(restored.maxAppVersion, "2.9.0");
      expect(restored.appVersion, "2.0.0");
      expect(restored.localizations, hasLength(2));
    });

    test("AnnouncementCatalog full round-trip", () {
      final catalog = AnnouncementCatalog(
        schemaVersion: 1,
        pages: [
          PageSummary(
            uuid: "page-1",
            publishedAt: DateTime.utc(2026, 1, 1),
            minAppVersion: "1.0.0",
            channels: ["stable"],
            count: 5,
            active: false,
          ),
          PageSummary(
            uuid: "page-2",
            publishedAt: DateTime.utc(2026, 6, 1),
            minAppVersion: "2.0.0",
            channels: ["stable", "beta"],
            count: 10,
            active: true,
          ),
        ],
      );
      final restored = AnnouncementCatalog.fromJson(
        jsonDecode(jsonEncode(catalog.toJson())) as Map<String, dynamic>,
      );
      expect(restored, catalog);
      expect(restored.pages, hasLength(2));
    });

    test("AnnouncementState with all fields round-trip", () {
      final state = AnnouncementState(
        schemaVersion: 1,
        readIds: ["a", "b", "c"],
        dismissedIds: ["x"],
      );
      final restored = AnnouncementState.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
      );
      expect(restored, state);
    });

    test("AnnouncementRecord value equality", () {
      final record1 = AnnouncementRecord(
        id: "entry-1",
        source: AnnouncementEntrySource.remote,
        title: "Title",
        summary: "Summary",
        bodyHash: "hash",
        publishedAt: DateTime.utc(2026, 1, 1),
        localeCode: "en",
        tags: [],
        startup: false,
      );
      final record2 = AnnouncementRecord(
        id: "entry-1",
        source: AnnouncementEntrySource.remote,
        title: "Title",
        summary: "Summary",
        bodyHash: "hash",
        publishedAt: DateTime.utc(2026, 1, 1),
        localeCode: "en",
        tags: [],
        startup: false,
      );
      expect(record1, record2);
      expect(record1.hashCode, record2.hashCode);
    });

    test("AnnouncementRecord from bundled source", () {
      final record = AnnouncementRecord(
        id: "bundled-1",
        source: AnnouncementEntrySource.bundled,
        title: "Welcome",
        summary: "Welcome to the app",
        bodyHash: "welcome_hash",
        publishedAt: DateTime.utc(2026, 1, 1),
        localeCode: "en",
        isRead: true,
        isDismissed: false,
      );
      expect(record.source, AnnouncementEntrySource.bundled);
      expect(record.isRead, isTrue);
    });

    test("AnnouncementRecord retains entry reference", () {
      final entry = AnnouncementEntry(
        id: "entry-1",
        publishedAt: DateTime.utc(2026, 1, 1),
        tags: ["news"],
        startup: true,
        channels: ["stable"],
        platforms: [AnnouncementPlatform.android],
        appVersion: "2.0.0",
        localizations: {
          "en": LocalizationMeta(title: "Title", summary: "Summary", bodyHash: "hash"),
        },
      );
      final record = AnnouncementRecord(
        id: entry.id,
        source: AnnouncementEntrySource.remote,
        title: "Title",
        summary: "Summary",
        bodyHash: "hash",
        publishedAt: entry.publishedAt,
        localeCode: "en",
        tags: entry.tags,
        startup: entry.startup,
        appVersion: entry.appVersion,
        entry: entry,
      );
      expect(record.entry, entry);
      expect(record.entry!.channels, ["stable"]);
      expect(record.entry!.platforms, [AnnouncementPlatform.android]);
      expect(record.entry!.localizations["en"]!.title, "Title");
    });
  });
}
