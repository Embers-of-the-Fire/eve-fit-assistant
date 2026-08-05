@TestOn("vm")
library;

import "dart:io";

import "package:eve_fit_assistant/storage/repo/localization_db.dart";
import "package:eve_fit_assistant/storage/repo/localization_db_native.dart";
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
  db.execute(
    "INSERT INTO strings(locale, id, value) VALUES (?, ?, ?)",
    ["en", 1001, "Gallente Frigate"],
  );
  db.execute("INSERT INTO strings(locale, id, value) VALUES (?, ?, ?)", ["en", 1002, "Test Item"]);
  db.execute("INSERT INTO strings(locale, id, value) VALUES (?, ?, ?)", ["zh", 1001, "加伦特护卫舰"]);
  db.execute("INSERT INTO strings(locale, id, value) VALUES (?, ?, ?)", ["zh", 1003, ""]);
  db.close();
}

Future<SqliteDatabase> _openFixtureDb(String path) async => SqliteDatabase(path: path);

void main() {
  late Directory tempDir;
  late SqliteDatabase db;
  late LocalizationDbService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("localization_db_test");
    final dbPath = p.join(tempDir.path, "fixture.db");
    _writeFixtureDb(dbPath);
    db = await _openFixtureDb(dbPath);
    service = LocalizationDbService.fromDatabase(db);
  });

  tearDown(() async {
    await service.close();
    await tempDir.delete(recursive: true);
  });

  test("resolves names per locale", () async {
    expect(await service.localizedName(1001, "en"), "Gallente Frigate");
    expect(await service.localizedName(1001, "zh"), "加伦特护卫舰");
    expect(await service.localizedName(1002, "en"), "Test Item");
  });

  test("returns empty string for unknown ids and locales", () async {
    expect(await service.localizedName(9999, "en"), "");
    expect(await service.localizedName(1002, "zh"), "");
    expect(await service.localizedName(1001, "fr"), "");
  });

  test("empty values resolve to empty string", () async {
    expect(await service.localizedName(1003, "zh"), "");
  });

  test("concurrent lookups for the same id share one query", () async {
    final results = await Future.wait([
      service.localizedName(1001, "en"),
      service.localizedName(1001, "en"),
      service.localizedName(1002, "en"),
    ]);
    expect(results, ["Gallente Frigate", "Gallente Frigate", "Test Item"]);
  });

  test("localizedNames batch-resolves and omits missing ids", () async {
    final names = await service.localizedNames([1001, 1002, 9999], "en");
    expect(names, {1001: "Gallente Frigate", 1002: "Test Item"});
  });

  test("localizedNames excludes empty values", () async {
    final names = await service.localizedNames([1001, 1003], "zh");
    expect(names, {1001: "加伦特护卫舰"});
  });

  test("localizedNames returns empty map for empty input", () async {
    expect(await service.localizedNames(const [], "en"), isEmpty);
  });

  test("misses are cached and not queried again", () async {
    expect(await service.localizedName(9999, "en"), "");
    // Second lookup must complete without touching the database again.
    expect(await service.localizedName(9999, "en"), "");
  });

  test("close completes pending lookups with empty strings", () async {
    final pending = service.localizedName(1001, "en");
    await service.close();
    expect(await pending, "");
  });

  group("openNativeLocalizationDb (read-only factory)", () {
    test("opens a blob database read-only without creating WAL siblings", () async {
      final dir = await Directory.systemTemp.createTemp("localization_ro_test");
      try {
        final dbPath = p.join(dir.path, "localization.db");
        _writeFixtureDb(dbPath);

        final ro = openNativeLocalizationDb(dbPath);
        final value = await ro.getOptional(
          "SELECT value FROM strings WHERE locale = ? AND id = ?",
          ["zh", 1001],
        );
        expect(value?["value"], "加伦特护卫舰");

        // Writes must be rejected on the read-only connection.
        await expectLater(
          ro.execute("INSERT INTO strings(locale, id, value) VALUES ('en', 1, 'x')"),
          throwsA(anything),
        );

        await ro.close();

        // No journal/WAL sidecars may appear next to the blob file.
        expect(File("$dbPath-wal").existsSync(), isFalse);
        expect(File("$dbPath-shm").existsSync(), isFalse);
        expect(File("$dbPath-journal").existsSync(), isFalse);
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
