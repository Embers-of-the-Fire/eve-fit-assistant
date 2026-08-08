@TestOn("vm")
library;

import "dart:io";

import "package:eve_fit_assistant/storage/repo/agent_resource_db.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;
import "package:sqlite3/sqlite3.dart" as sqlite;
import "package:sqlite_async/sqlite_async.dart";

void _writeFixtureDb(String path) {
  final db = sqlite.sqlite3.open(path);
  db.execute("CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)");
  db.execute(
    "CREATE TABLE type_names(locale TEXT NOT NULL, id INTEGER NOT NULL, value TEXT NOT NULL, "
    "PRIMARY KEY(locale, id)) WITHOUT ROWID",
  );
  db.execute("INSERT INTO meta(key, value) VALUES ('schema_version', '1')");
  db.execute("INSERT INTO type_names(locale, id, value) VALUES (?, ?, ?)", [
    "en",
    3839,
    "Large Shield Extender I",
  ]);
  db.execute("INSERT INTO type_names(locale, id, value) VALUES (?, ?, ?)", [
    "en",
    3841,
    "Large Shield Extender II",
  ]);
  db.execute("INSERT INTO type_names(locale, id, value) VALUES (?, ?, ?)", [
    "en",
    16146,
    "CONCORD Large Shield Extender",
  ]);
  db.execute("INSERT INTO type_names(locale, id, value) VALUES (?, ?, ?)", [
    "zh",
    3839,
    "大型护盾扩充器I",
  ]);
  db.execute("INSERT INTO type_names(locale, id, value) VALUES (?, ?, ?)", ["zh", 40000, ""]);
  db.close();
}

void main() {
  late Directory tempDir;
  late SqliteDatabase db;
  late AgentResourceDbService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("agent_resource_db_test");
    final dbPath = p.join(tempDir.path, "fixture.db");
    _writeFixtureDb(dbPath);
    db = SqliteDatabase(path: dbPath);
    service = AgentResourceDbService.fromDatabase(db);
  });

  tearDown(() async {
    await service.close();
    await tempDir.delete(recursive: true);
  });

  test("substring search returns real type ids ordered by shortest name", () async {
    final hits = await service.searchTypeNames("large shield extender", "en");
    expect(hits, {
      16146: "CONCORD Large Shield Extender",
      3839: "Large Shield Extender I",
      3841: "Large Shield Extender II",
    });
  });

  test("search is locale-scoped", () async {
    final hits = await service.searchTypeNames("护盾", "zh");
    expect(hits, {3839: "大型护盾扩充器I"});
    expect(await service.searchTypeNames("护盾", "en"), isEmpty);
  });

  test("search is case-insensitive", () async {
    final hits = await service.searchTypeNames("concord large", "en");
    expect(hits, {16146: "CONCORD Large Shield Extender"});
  });

  test("empty and blank queries match nothing", () async {
    expect(await service.searchTypeNames("", "en"), isEmpty);
    expect(await service.searchTypeNames("   ", "en"), isEmpty);
  });

  test("LIKE wildcards in the query are escaped", () async {
    expect(await service.searchTypeNames("%", "en"), isEmpty);
    expect(await service.searchTypeNames("_", "en"), isEmpty);
  });

  test("empty values are excluded", () async {
    expect(await service.searchTypeNames("大型", "zh"), isNot(contains(40000)));
  });

  test("limit caps the result count", () async {
    final hits = await service.searchTypeNames("large", "en", limit: 2);
    expect(hits.length, 2);
  });

  test("results after close are empty", () async {
    await service.close();
    expect(await service.searchTypeNames("large", "en"), isEmpty);
  });
}
