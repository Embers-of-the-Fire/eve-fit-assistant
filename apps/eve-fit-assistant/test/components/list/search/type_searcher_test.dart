@TestOn("vm")
library;

import "dart:io";

import "package:eve_fit_assistant/components/list/search/type_searcher.dart";
import "package:eve_fit_assistant/storage/repo/localization_db.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;
import "package:sqlite3/sqlite3.dart" as sqlite;
import "package:sqlite_async/sqlite_async.dart";

void _writeFixtureDb(String path) {
  final db = sqlite.sqlite3.open(path);
  db.execute("CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)");
  db.execute(
    "CREATE TABLE strings(locale TEXT NOT NULL, id INTEGER NOT NULL, value TEXT NOT NULL, "
    "PRIMARY KEY(locale, id)) WITHOUT ROWID",
  );
  db.execute("INSERT INTO meta(key, value) VALUES ('schema_version', '1')");
  final rows = {
    "en": {5001: "Rifter", 5002: "Frigate", 5003: "Rifter II"},
    "zh": {5001: "裂谷级", 5004: "四重子异种等离子弹药 M"},
  };
  for (final locale in rows.keys) {
    for (final entry in rows[locale]!.entries) {
      db.execute("INSERT INTO strings(locale, id, value) VALUES (?, ?, ?)", [
        locale,
        entry.key,
        entry.value,
      ]);
    }
  }
  db.close();
}

void main() {
  late Directory tempDir;
  late SqliteDatabase db;
  late LocalizationDbService service;

  // The localization strings table is keyed by localization string id, a
  // namespace disjoint from type ids; 5002 models a group/market-group name
  // that no type name maps back to.
  const nameIdToTypeId = {5001: 1001, 5003: 1003, 5004: 1004};
  var locale = "en";

  late LocalizationTypeSearcher searcher;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("type_searcher_test");
    final dbPath = p.join(tempDir.path, "fixture.db");
    _writeFixtureDb(dbPath);
    db = await SqliteDatabase(path: dbPath);
    service = LocalizationDbService.fromDatabase(db);
    locale = "en";
    searcher = LocalizationTypeSearcher(
      localizationDb: () async => service,
      locale: () => locale,
      typeIdOfNameId: (nameId) => nameIdToTypeId[nameId],
    );
  });

  tearDown(() async {
    await service.close();
    await tempDir.delete(recursive: true);
  });

  test("maps name hits back to type ids, ordered by name length", () async {
    expect(await searcher.search("Rifter"), [1001, 1003]);
  });

  test("drops hits that name something other than a type", () async {
    expect(await searcher.search("Frigate"), isEmpty);
  });

  test("searches the active locale only", () async {
    locale = "zh";
    expect(await searcher.search("裂谷"), [1001]);
    expect(await searcher.search("Rifter"), isEmpty);
  });

  test("whitespace-separated tokens must all match (AND semantics)", () async {
    locale = "zh";
    expect(await searcher.search("异种 M"), [1004]);
    expect(await searcher.search("异种   M"), [1004]);
    expect(await searcher.search("异种 L"), isEmpty);
    expect(await searcher.search("裂谷 M"), isEmpty);
  });

  test("blank queries yield no results", () async {
    expect(await searcher.search(""), isEmpty);
    expect(await searcher.search("   "), isEmpty);
  });

  test("unavailable localization database yields no results", () async {
    final searcher = LocalizationTypeSearcher(
      localizationDb: () async => null,
      locale: () => "en",
      typeIdOfNameId: (nameId) => nameIdToTypeId[nameId],
    );
    expect(await searcher.search("Rifter"), isEmpty);
  });

  test("failed localization database initialization yields no results", () async {
    final searcher = LocalizationTypeSearcher(
      localizationDb: () => Future.error(StateError("localization db failed to load")),
      locale: () => "en",
      typeIdOfNameId: (nameId) => nameIdToTypeId[nameId],
    );
    expect(await searcher.search("Rifter"), isEmpty);
  });
}
