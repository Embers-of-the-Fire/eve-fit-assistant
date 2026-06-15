import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:crypto/crypto.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/repo/announcements.dart";
import "package:eve_fit_assistant/storage/repo/models/announcement.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:path/path.dart" as p;

void main() {
  late String tempDir;
  late AnnouncementService announcementService;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_announcement_test_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.tempPath = p.join(tempDir, "tmp");
    announcementService = const AnnouncementService();
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group("AnnouncementService index read/write", () {
    test("readIndex returns default empty index when file does not exist", () {
      final index = announcementService.readIndex();
      expect(index.schemaVersion, 2);
      expect(index.records, isEmpty);
    });

    test("writeIndex then readIndex round-trip", () {
      final entry = AnnouncementIndexEntry(
        id: "ann-001",
        contentHash: "abc123",
        isVersionUpdate: true,
        isRead: false,
      );
      final index = AnnouncementIndex(schemaVersion: 2, records: IList([entry]));
      announcementService.writeIndex(index);

      final restored = announcementService.readIndex();
      expect(restored.schemaVersion, 2);
      expect(restored.records.length, 1);
      expect(restored.records.first.id, "ann-001");
      expect(restored.records.first.contentHash, "abc123");
      expect(restored.records.first.isVersionUpdate, isTrue);
      expect(restored.records.first.isRead, isFalse);
    });

    test("after writeIndex, no .tmp file remains", () {
      final index = AnnouncementIndex(schemaVersion: 2);
      announcementService.writeIndex(index);

      final tmpFile = File("${RepoPaths.announcementsIndexPath}.tmp");
      expect(tmpFile.existsSync(), isFalse);
      expect(File(RepoPaths.announcementsIndexPath).existsSync(), isTrue);
    });
  });

  group("AnnouncementService record read/write", () {
    test("readRecord returns None when file does not exist", () {
      expect(announcementService.readRecord("nonexistent"), const None());
    });

    test("writeRecord then readRecord round-trip preserves all fields", () {
      final record = AnnouncementRecord(
        id: "ann-001",
        firstPublishedAt: "2024-01-15T10:30:00Z",
        updatedAt: "2024-01-20T12:00:00Z",
        contentHash: "hash-001",
        recordVersion: 1,
        title: IMap<String, String>({"en": "Hello", "zh": "你好"}),
        excerpt: IMap<String, String>({"en": "Summary", "zh": "摘要"}),
        tags: IList<String>(["important", "update"]),
        versionRange: VersionRange(min: "1.0", max: "2.0"),
        isVersionUpdate: true,
      );
      announcementService.writeRecord(record);

      final restored = announcementService.readRecord("ann-001");
      expect(restored.isSome(), isTrue);
      final r = restored.toNullable()!;
      expect(r.id, "ann-001");
      expect(r.firstPublishedAt, "2024-01-15T10:30:00Z");
      expect(r.updatedAt, "2024-01-20T12:00:00Z");
      expect(r.contentHash, "hash-001");
      expect(r.recordVersion, 1);
      expect(r.title["en"], "Hello");
      expect(r.title["zh"], "你好");
      expect(r.excerpt["en"], "Summary");
      expect(r.excerpt["zh"], "摘要");
      expect(r.tags, IList<String>(["important", "update"]));
      expect(r.versionRange?.min, "1.0");
      expect(r.versionRange?.max, "2.0");
      expect(r.isVersionUpdate, isTrue);
    });

    test("writeRecord with minimal fields round-trips", () {
      final record = AnnouncementRecord(
        id: "minimal",
        firstPublishedAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z",
        contentHash: "minimal-hash",
      );
      announcementService.writeRecord(record);

      final restored = announcementService.readRecord("minimal").toNullable()!;
      expect(restored.title, IMap<String, String>.empty());
      expect(restored.excerpt, IMap<String, String>.empty());
      expect(restored.tags, IList<String>.empty());
      expect(restored.versionRange, isNull);
      expect(restored.isVersionUpdate, isFalse);
      expect(restored.recordVersion, 1);
    });

    test("after writeRecord, no .tmp file remains", () {
      final record = AnnouncementRecord(
        id: "ann-tmp-test",
        firstPublishedAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z",
        contentHash: "tmp-test-hash",
      );
      announcementService.writeRecord(record);

      final tmpFile = File("${RepoPaths.announcementRegistryPath("ann-tmp-test")}.tmp");
      expect(tmpFile.existsSync(), isFalse);
      expect(File(RepoPaths.announcementRegistryPath("ann-tmp-test")).existsSync(), isTrue);
    });
  });

  group("AnnouncementService locale content read/write", () {
    test("readContent returns None when file does not exist", () {
      expect(announcementService.readContent("en", "nonexistent"), const None());
    });

    test("writeContent then readContent for en locale", () {
      final markdown = "# Hello World\n\nThis is a test announcement.";
      announcementService.writeContent("en", "ann-001", markdown);

      final restored = announcementService.readContent("en", "ann-001");
      expect(restored.isSome(), isTrue);
      expect(restored.toNullable()!, markdown);
    });

    test("writeContent then readContent for zh locale", () {
      final markdown = "# 公告\n\n测试内容。";
      announcementService.writeContent("zh", "ann-001", markdown);

      final restored = announcementService.readContent("zh", "ann-001");
      expect(restored.isSome(), isTrue);
      expect(restored.toNullable()!, markdown);
    });

    test("multiple locales can coexist", () {
      announcementService.writeContent("en", "ann-001", "English content");
      announcementService.writeContent("zh", "ann-001", "Chinese content");
      announcementService.writeContent("ja", "ann-001", "Japanese content");

      expect(announcementService.readContent("en", "ann-001").toNullable(), "English content");
      expect(announcementService.readContent("zh", "ann-001").toNullable(), "Chinese content");
      expect(announcementService.readContent("ja", "ann-001").toNullable(), "Japanese content");
    });

    test("after writeContent, no .tmp file remains", () {
      announcementService.writeContent("en", "ann-001", "test");

      final tmpFile = File("${RepoPaths.announcementFilePath("en", "ann-001")}.tmp");
      expect(tmpFile.existsSync(), isFalse);
      expect(File(RepoPaths.announcementFilePath("en", "ann-001")).existsSync(), isTrue);
    });
  });

  group("AnnouncementService computeContentHash", () {
    test("produces a 64-char hex SHA-256 digest", () {
      final record = AnnouncementRecord(
        id: "ann-001",
        firstPublishedAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-20T12:00:00Z",
        contentHash: "initial",
        title: IMap<String, String>({"en": "Hello"}),
      );
      final localeContents = <String, String>{"en": "# Test content"};

      final hash = announcementService.computeContentHash(record, localeContents);
      expect(hash.length, 64);

      // Verify it's valid hex
      expect(hash, matches("^[0-9a-f]"));
      for (var i = 0; i < hash.length; i++) {
        expect("0123456789abcdef".contains(hash[i]), isTrue);
      }
    });

    test("changes if locale content changes", () {
      final record = AnnouncementRecord(
        id: "ann-001",
        firstPublishedAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-20T12:00:00Z",
        contentHash: "initial",
      );
      final contents1 = <String, String>{"en": "Content A"};
      final contents2 = <String, String>{"en": "Content B"};

      final hash1 = announcementService.computeContentHash(record, contents1);
      final hash2 = announcementService.computeContentHash(record, contents2);

      expect(hash1, isNot(hash2));
    });

    test("changes if updatedAt changes", () {
      final record1 = AnnouncementRecord(
        id: "ann-001",
        firstPublishedAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-20T12:00:00Z",
        contentHash: "initial",
      );
      final record2 = AnnouncementRecord(
        id: "ann-001",
        firstPublishedAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-21T12:00:00Z",
        contentHash: "initial",
      );
      final localeContents = <String, String>{"en": "Same content"};

      final hash1 = announcementService.computeContentHash(record1, localeContents);
      final hash2 = announcementService.computeContentHash(record2, localeContents);

      expect(hash1, isNot(hash2));
    });

    test("changes if record id changes", () {
      final record1 = AnnouncementRecord(
        id: "ann-001",
        firstPublishedAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-20T12:00:00Z",
        contentHash: "initial",
      );
      final record2 = AnnouncementRecord(
        id: "ann-002",
        firstPublishedAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-20T12:00:00Z",
        contentHash: "initial",
      );
      final localeContents = <String, String>{"en": "Same content"};

      final hash1 = announcementService.computeContentHash(record1, localeContents);
      final hash2 = announcementService.computeContentHash(record2, localeContents);

      expect(hash1, isNot(hash2));
    });

    test("same inputs produce same hash (deterministic)", () {
      final record = AnnouncementRecord(
        id: "ann-001",
        firstPublishedAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-20T12:00:00Z",
        contentHash: "initial",
      );
      final localeContents = <String, String>{"en": "Content", "zh": "内容"};

      final hash1 = announcementService.computeContentHash(record, localeContents);
      final hash2 = announcementService.computeContentHash(record, localeContents);

      expect(hash1, hash2);
    });

    test("XOR of locale hashes works correctly", () {
      final record = AnnouncementRecord(
        id: "ann-001",
        firstPublishedAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-20T12:00:00Z",
        contentHash: "initial",
      );

      // The hash with both locales should differ from hash with single locale
      final singleEn = <String, String>{"en": "Content"};
      final both = <String, String>{"en": "Content", "zh": "内容"};

      final hashSingle = announcementService.computeContentHash(record, singleEn);
      final hashBoth = announcementService.computeContentHash(record, both);

      expect(hashSingle, isNot(hashBoth));
    });

    test("empty locale contents produces a hash", () {
      final record = AnnouncementRecord(
        id: "ann-001",
        firstPublishedAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-20T12:00:00Z",
        contentHash: "initial",
      );
      final hash = announcementService.computeContentHash(record, <String, String>{});
      expect(hash.length, 64);
    });
  });

  group("AnnouncementService updateAnnouncementIndex", () {
    test("adds a new entry when id does not exist", () {
      announcementService.updateAnnouncementIndex(
        "ann-001",
        isVersionUpdate: true,
        contentHash: "hash-001",
      );

      final index = announcementService.readIndex();
      expect(index.records.length, 1);
      expect(index.records.first.id, "ann-001");
      expect(index.records.first.contentHash, "hash-001");
      expect(index.records.first.isVersionUpdate, isTrue);
      expect(index.records.first.isRead, isFalse);
    });

    test("updates existing entry contentHash without changing isVersionUpdate", () {
      // First insert
      announcementService.updateAnnouncementIndex(
        "ann-001",
        isVersionUpdate: false,
        contentHash: "hash-old",
      );

      // Then update only contentHash
      announcementService.updateAnnouncementIndex("ann-001", contentHash: "hash-new");

      final index = announcementService.readIndex();
      expect(index.records.length, 1);
      expect(index.records.first.contentHash, "hash-new");
      expect(index.records.first.isVersionUpdate, isFalse);
      expect(index.records.first.isRead, isFalse);
    });

    test("updates existing entry isVersionUpdate", () {
      announcementService.updateAnnouncementIndex("ann-001", contentHash: "hash-001");
      announcementService.updateAnnouncementIndex("ann-001", isVersionUpdate: true);

      final index = announcementService.readIndex();
      expect(index.records.first.isVersionUpdate, isTrue);
      expect(index.records.first.contentHash, "hash-001");
    });

    test("multiple entries can coexist", () {
      announcementService.updateAnnouncementIndex("ann-001", contentHash: "h1");
      announcementService.updateAnnouncementIndex("ann-002", contentHash: "h2");
      announcementService.updateAnnouncementIndex("ann-003", contentHash: "h3");

      final index = announcementService.readIndex();
      expect(index.records.length, 3);
      expect(index.records.map((e) => e.id).toList(), ["ann-001", "ann-002", "ann-003"]);
      expect(index.records.map((e) => e.contentHash).toList(), ["h1", "h2", "h3"]);
    });
  });

  group("AnnouncementService markRead", () {
    test("sets isRead to true on an existing entry", () {
      announcementService.updateAnnouncementIndex(
        "ann-001",
        contentHash: "hash-001",
        isVersionUpdate: true,
      );

      announcementService.markRead("ann-001");

      final index = announcementService.readIndex();
      expect(index.records.first.isRead, isTrue);
      expect(index.records.first.isVersionUpdate, isTrue);
      expect(index.records.first.contentHash, "hash-001");
    });

    test("markRead on already-read entry is idempotent", () {
      announcementService.updateAnnouncementIndex("ann-001", contentHash: "hash-001");
      announcementService.markRead("ann-001");
      announcementService.markRead("ann-001");

      final index = announcementService.readIndex();
      expect(index.records.first.isRead, isTrue);
      expect(index.records.length, 1);
    });

    test("markRead on nonexistent id returns early without error", () {
      // Should not throw
      announcementService.markRead("nonexistent");

      final index = announcementService.readIndex();
      expect(index.records, isEmpty);
    });

    test("markRead does not modify other entries", () {
      announcementService.updateAnnouncementIndex("ann-001", contentHash: "h1");
      announcementService.updateAnnouncementIndex("ann-002", contentHash: "h2");

      announcementService.markRead("ann-001");

      final index = announcementService.readIndex();
      final e1 = index.records.firstWhere((e) => e.id == "ann-001");
      final e2 = index.records.firstWhere((e) => e.id == "ann-002");
      expect(e1.isRead, isTrue);
      expect(e2.isRead, isFalse);
    });
  });
}
