import "dart:convert";

import "package:eve_fit_assistant/storage/repo/models/announcement.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("AnnouncementRecord", () {
    test("JSON round-trip with full data", () {
      final record = AnnouncementRecord(
        id: "ann-001",
        recordVersion: 1,
        title: IMap({"en": "Update Available", "zh": "更新可用"}),
        excerpt: IMap({"en": "New version 2.0.0", "zh": "新版本 2.0.0"}),
        tags: IList(["update", "release"]),
        firstPublishedAt: "2024-01-15T00:00:00Z",
        updatedAt: "2024-01-16T00:00:00Z",
        contentHash: "content-hash-001",
        isVersionUpdate: true,
      );
      final restored = AnnouncementRecord.fromJson(
        jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>,
      );
      expect(restored, record);
    });

    test("JSON round-trip with empty collections", () {
      final record = AnnouncementRecord(
        id: "ann-002",
        firstPublishedAt: "2024-01-15T00:00:00Z",
        updatedAt: "2024-01-16T00:00:00Z",
        contentHash: "content-hash-002",
      );
      final restored = AnnouncementRecord.fromJson(
        jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>,
      );
      expect(restored.tags.isEmpty, isTrue);
      expect(restored.title.isEmpty, isTrue);
      expect(restored.isVersionUpdate, false);
      expect(restored, record);
    });

    test("fromJson with known shape", () {
      final json =
          jsonDecode(
                '{'
                '  "id": "ann-001",'
                '  "recordVersion": 1,'
                '  "title": {"en": "Hello"},'
                '  "excerpt": {"en": "World"},'
                '  "tags": ["news"],'
                '  "firstPublishedAt": "2024-01-15T00:00:00Z",'
                '  "updatedAt": "2024-01-16T00:00:00Z",'
                '  "contentHash": "hash-001",'
                '  "isVersionUpdate": false'
                '}',
              )
              as Map<String, dynamic>;
      final record = AnnouncementRecord.fromJson(json);
      expect(record.id, "ann-001");
      expect(record.title["en"], "Hello");
      expect(record.tags, IList(["news"]));
    });
  });

  group("AnnouncementIndexEntry", () {
    test("JSON round-trip", () {
      final entry = AnnouncementIndexEntry(
        id: "ann-001",
        contentHash: "hash-001",
        isVersionUpdate: true,
        isRead: false,
      );
      final restored = AnnouncementIndexEntry.fromJson(
        jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>,
      );
      expect(restored, entry);
    });
  });

  group("AnnouncementIndex", () {
    test("JSON round-trip with records", () {
      final index = AnnouncementIndex(
        schemaVersion: 1,
        records: IList([
          AnnouncementIndexEntry(id: "ann-001", contentHash: "hash-001", isRead: true),
          AnnouncementIndexEntry(id: "ann-002", contentHash: "hash-002", isVersionUpdate: true),
        ]),
      );
      final restored = AnnouncementIndex.fromJson(
        jsonDecode(jsonEncode(index.toJson())) as Map<String, dynamic>,
      );
      expect(restored, index);
      expect(restored.records.length, 2);
    });

    test("JSON round-trip with empty records", () {
      final index = AnnouncementIndex(schemaVersion: 1);
      final restored = AnnouncementIndex.fromJson(
        jsonDecode(jsonEncode(index.toJson())) as Map<String, dynamic>,
      );
      expect(restored.records.isEmpty, isTrue);
      expect(restored, index);
    });
  });
}
