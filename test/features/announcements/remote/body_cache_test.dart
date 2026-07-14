import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/announcements/remote/body_cache.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  late String tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_body_cache_test_").path;
    PathProvider.cachesPath = tempDir;
  });

  tearDown(() {
    Directory(tempDir).deleteSync(recursive: true);
  });

  group("AnnouncementBodyCache", () {
    test("init creates cache directory", () async {
      await AnnouncementBodyCache.init();
      expect(Directory("$tempDir/announcements/bodies").existsSync(), isTrue);
    });

    test("put and get round-trip", () async {
      const hash = "a1b2c3d4e5f6789012345678901234567890abcd12345678901234567890abcdef";
      const content = "# Hello World\n\nThis is a test body.";
      await AnnouncementBodyCache.put(hash, content);
      final result = await AnnouncementBodyCache.get(hash);
      expect(result, content);
    });

    test("exists returns true after put", () async {
      const hash = "deadbeef12345678901234567890123456789012345678901234567890abcdef";
      await AnnouncementBodyCache.put(hash, "test");
      expect(AnnouncementBodyCache.exists(hash), isTrue);
    });

    test("exists returns false for missing hash", () {
      expect(
        AnnouncementBodyCache.exists(
          "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
        ),
        isFalse,
      );
    });

    test("get returns null for missing hash", () async {
      expect(
        await AnnouncementBodyCache.get(
          "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
        ),
        isNull,
      );
    });

    test("file is stored with two-char prefix sharding", () async {
      const hash = "abcdef12345678901234567890123456789012345678901234567890abcdef";
      const content = "sharded content";
      await AnnouncementBodyCache.put(hash, content);

      final file = File(
        "$tempDir/announcements/bodies/ab/abcdef12345678901234567890123456789012345678901234567890abcdef.md",
      );
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), content);
    });

    test("put overwrites existing content", () async {
      const hash = "1111111111111111111111111111111111111111111111111111111111111111";
      await AnnouncementBodyCache.put(hash, "first");
      await AnnouncementBodyCache.put(hash, "second");
      expect(await AnnouncementBodyCache.get(hash), "second");
    });

    test("multiple hashes with same prefix share directory", () async {
      const hash1 = "aa00000000000000000000000000000000000000000000000000000000000000";
      const hash2 = "aa11111111111111111111111111111111111111111111111111111111111111";
      await AnnouncementBodyCache.put(hash1, "one");
      await AnnouncementBodyCache.put(hash2, "two");

      expect(await AnnouncementBodyCache.get(hash1), "one");
      expect(await AnnouncementBodyCache.get(hash2), "two");

      final dir = Directory("$tempDir/announcements/bodies/aa");
      expect(dir.listSync().length, 2);
    });

    test("prune deletes unreferenced files", () async {
      const keepHash = "aa00000000000000000000000000000000000000000000000000000000000000";
      const dropHash = "bb11111111111111111111111111111111111111111111111111111111111111";
      await AnnouncementBodyCache.put(keepHash, "keep");
      await AnnouncementBodyCache.put(dropHash, "drop");

      await AnnouncementBodyCache.prune(referencedHashes: {keepHash});

      expect(await AnnouncementBodyCache.get(keepHash), "keep");
      expect(await AnnouncementBodyCache.get(dropHash), isNull);
    });

    test("prune keeps all files when all are referenced", () async {
      const hash1 = "aa00000000000000000000000000000000000000000000000000000000000000";
      const hash2 = "bb11111111111111111111111111111111111111111111111111111111111111";
      await AnnouncementBodyCache.put(hash1, "one");
      await AnnouncementBodyCache.put(hash2, "two");

      await AnnouncementBodyCache.prune(referencedHashes: {hash1, hash2});

      expect(await AnnouncementBodyCache.get(hash1), "one");
      expect(await AnnouncementBodyCache.get(hash2), "two");
    });

    test("prune on empty directory is a no-op", () async {
      await AnnouncementBodyCache.prune(referencedHashes: {});
      // No crash, no files created.
      expect(Directory("$tempDir/announcements/bodies").existsSync(), isFalse);
    });
  });
}
