import "dart:io";

import "package:eve_fit_assistant/features/manual/manual.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;
import "package:sqlite_async/sqlite_async.dart";

Future<SqliteDatabase> _createFixtureDb(String path) async {
  final db = SqliteDatabase(path: path);
  await db.execute(
    "CREATE VIRTUAL TABLE manual_fts_zh USING fts5("
    "doc_id UNINDEXED, title, body, tokenize='trigram')",
  );
  await db.execute(
    "CREATE VIRTUAL TABLE manual_fts_en USING fts5("
    "doc_id UNINDEXED, title, body, tokenize='porter unicode61')",
  );

  await db.execute(
    "INSERT INTO manual_fts_zh(doc_id, title, body) VALUES (?, ?, ?)",
    ["fitting/modules", "装配模块", "本章节介绍如何给舰船装配模块。 fitting modules"],
  );
  await db.execute(
    "INSERT INTO manual_fts_zh(doc_id, title, body) VALUES (?, ?, ?)",
    [
      "getting-started/browse-ships",
      "浏览舰船",
      "了解如何在舰船浏览器中查找和筛选舰船。 getting started browse ships",
    ],
  );

  await db.execute(
    "INSERT INTO manual_fts_en(doc_id, title, body) VALUES (?, ?, ?)",
    [
      "fitting/modules",
      "fitting modules",
      "learn how the fitted modules are fitted on your ship. fitting modules",
    ],
  );
  await db.execute(
    "INSERT INTO manual_fts_en(doc_id, title, body) VALUES (?, ?, ?)",
    [
      "getting-started/browse-ships",
      "browsing ships",
      "find and filter ships in the ship browser. getting started browse ships",
    ],
  );
  return db;
}

void main() {
  late Directory tempDir;
  late SqliteDatabase db;
  late ManualSearchService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("manual_search_test");
    db = await _createFixtureDb(p.join(tempDir.path, "fixture.db"));
    service = ManualSearchService.fromDatabase(db);
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  group("zh trigram search", () {
    test("substring query matches the right doc with a highlighted snippet", () async {
      final results = await service.search("装配模块", "zh");

      expect(results, isNotEmpty);
      expect(results.first.docId, "fitting/modules");
      expect(results.first.titleRanges, isNotEmpty);
      expect(results.first.snippet.text, contains("装配模块"));
      final range = results.first.snippet.ranges.first;
      expect(
        results.first.snippet.text.substring(range.start, range.end),
        "装配模块",
      );
    });

    test("doc-id tokens are searchable", () async {
      final results = await service.search("browse ships", "zh");

      expect(results.map((r) => r.docId), contains("getting-started/browse-ships"));
    });

    test("short query falls back to LIKE", () async {
      final results = await service.search("舰船", "zh");

      expect(results, hasLength(2));
    });

    test("short query prefers title matches", () async {
      final results = await service.search("装配", "zh");

      expect(results.first.docId, "fitting/modules");
    });

    test("no match yields an empty result", () async {
      final results = await service.search("不存在的内容xyz", "zh");

      expect(results, isEmpty);
    });
  });

  group("en porter search", () {
    test("stemmed query matches", () async {
      final results = await service.search("fitting", "en");

      expect(results.map((r) => r.docId), contains("fitting/modules"));
    });

    test("prefix query supports as-you-type", () async {
      final results = await service.search("brows", "en");

      expect(results.map((r) => r.docId), contains("getting-started/browse-ships"));
    });

    test("title matches rank above body-only matches", () async {
      final results = await service.search("modules", "en");

      expect(results.first.docId, "fitting/modules");
    });
  });

  group("locale handling", () {
    test("regional zh locale codes use the zh index", () async {
      final results = await service.search("装配模块", "zh-Hans-CN");

      expect(results.first.docId, "fitting/modules");
    });

    test("empty query returns nothing", () async {
      expect(await service.search("   ", "zh"), isEmpty);
      expect(await service.search("", "en"), isEmpty);
    });
  });
}
