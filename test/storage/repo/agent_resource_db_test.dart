@TestOn("vm")
library;

import "dart:io";

import "package:eve_fit_assistant/storage/repo/agent_resource_db.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;
import "package:sqlite3/sqlite3.dart" as sqlite;
import "package:sqlite_async/sqlite_async.dart";

void _insertTypeName(
  sqlite.Database db,
  String locale,
  int id,
  String value, {
  int? groupId,
  int? categoryId,
  int? slotIndex,
  String? slotKind,
}) {
  db.execute(
    "INSERT INTO type_names(locale, id, value, group_id, category_id, slot_index, slot_kind) "
    "VALUES (?, ?, ?, ?, ?, ?, ?)",
    [locale, id, value, groupId, categoryId, slotIndex, slotKind],
  );
}

void _writeFixtureDb(String path) {
  final db = sqlite.sqlite3.open(path);
  db.execute("CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)");
  db.execute(
    "CREATE TABLE type_names("
    "locale TEXT NOT NULL, id INTEGER NOT NULL, value TEXT NOT NULL, "
    "group_id INTEGER, category_id INTEGER, slot_index INTEGER, slot_kind TEXT, "
    "PRIMARY KEY(locale, id)) WITHOUT ROWID",
  );
  db.execute("INSERT INTO meta(key, value) VALUES ('schema_version', '2')");
  _insertTypeName(db, "en", 3839, "Large Shield Extender I", groupId: 115, categoryId: 7);
  _insertTypeName(db, "en", 3841, "Large Shield Extender II", groupId: 115, categoryId: 7);
  _insertTypeName(db, "en", 16146, "CONCORD Large Shield Extender", groupId: 115, categoryId: 7);
  _insertTypeName(
    db,
    "en",
    33516,
    "Large Crystal Alpha",
    groupId: 748,
    categoryId: 20,
    slotIndex: 1,
    slotKind: "implant",
  );
  _insertTypeName(
    db,
    "en",
    81083,
    "Large Halcyon Booster",
    groupId: 1735,
    categoryId: 20,
    slotIndex: 2,
    slotKind: "booster",
  );
  _insertTypeName(db, "zh", 3839, "大型护盾扩充器I", groupId: 115, categoryId: 7);
  _insertTypeName(db, "zh", 40000, "");
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
    final hits = await service.searchTypes("large shield extender", "en");
    expect(hits.map((hit) => hit.typeId), [3839, 3841, 16146]);
    expect(hits.map((hit) => hit.name), [
      "Large Shield Extender I",
      "Large Shield Extender II",
      "CONCORD Large Shield Extender",
    ]);
  });

  test("search is locale-scoped", () async {
    final hits = await service.searchTypes("护盾", "zh");
    expect(hits.map((hit) => hit.typeId), [3839]);
    expect(await service.searchTypes("护盾", "en"), isEmpty);
  });

  test("search is case-insensitive", () async {
    final hits = await service.searchTypes("concord large", "en");
    expect(hits.map((hit) => hit.typeId), [16146]);
  });

  test("empty and blank queries match nothing", () async {
    expect(await service.searchTypes("", "en"), isEmpty);
    expect(await service.searchTypes("   ", "en"), isEmpty);
  });

  test("LIKE wildcards in the query are escaped", () async {
    expect(await service.searchTypes("%", "en"), isEmpty);
    expect(await service.searchTypes("_", "en"), isEmpty);
  });

  test("empty values are excluded", () async {
    final hits = await service.searchTypes("大型", "zh");
    expect(hits.map((hit) => hit.typeId), isNot(contains(40000)));
  });

  test("limit caps the result count", () async {
    final hits = await service.searchTypes("large", "en", limit: 2);
    expect(hits.length, 2);
  });

  test("hits carry group, category, and slot metadata", () async {
    final hits = await service.searchTypes("crystal", "en");
    expect(hits, hasLength(1));
    final hit = hits.single;
    expect(hit.groupId, 748);
    expect(hit.categoryId, 20);
    expect(hit.slotIndex, 1);
    expect(hit.slotKind, "implant");
  });

  test("kind filter restricts results to one item kind", () async {
    final implants = await service.searchTypes("large", "en", kind: AgentSearchKind.implant);
    expect(implants.map((hit) => hit.typeId), [33516]);
    final boosters = await service.searchTypes("large", "en", kind: AgentSearchKind.booster);
    expect(boosters.map((hit) => hit.typeId), [81083]);
    final modules = await service.searchTypes("large", "en", kind: AgentSearchKind.module);
    expect(modules.map((hit) => hit.typeId), isNot(contains(33516)));
    final drones = await service.searchTypes("large", "en", kind: AgentSearchKind.drone);
    expect(drones, isEmpty);
  });

  test("results after close are empty", () async {
    await service.close();
    expect(await service.searchTypes("large", "en"), isEmpty);
  });
}
