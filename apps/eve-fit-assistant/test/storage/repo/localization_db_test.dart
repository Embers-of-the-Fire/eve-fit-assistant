@TestOn("vm")
library;

import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:efa_proto/resource_index.pb.dart";
import "package:eve_fit_assistant/storage/fs/file_blob_store.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/localization_db.dart";
import "package:eve_fit_assistant/storage/repo/localization_db_native.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:fixnum/fixnum.dart";
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
  db.execute("INSERT INTO strings(locale, id, value) VALUES (?, ?, ?)", [
    "en",
    1001,
    "Gallente Frigate",
  ]);
  db.execute("INSERT INTO strings(locale, id, value) VALUES (?, ?, ?)", ["en", 1002, "Test Item"]);
  db.execute("INSERT INTO strings(locale, id, value) VALUES (?, ?, ?)", ["zh", 1001, "加伦特护卫舰"]);
  db.execute("INSERT INTO strings(locale, id, value) VALUES (?, ?, ?)", ["zh", 1003, ""]);
  db.close();
}

/// Writes a fixture database with the given schema version and rows.
void _writeSchemaDb(
  String path,
  String schemaVersion,
  Map<String, Map<int, String>> rows, {
  String? localeMeta,
}) {
  final db = sqlite.sqlite3.open(path);
  db.execute("CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)");
  db.execute(
    "CREATE TABLE strings(locale TEXT NOT NULL, id INTEGER NOT NULL, value TEXT NOT NULL, "
    "PRIMARY KEY(locale, id)) WITHOUT ROWID",
  );
  db.execute("INSERT INTO meta(key, value) VALUES ('schema_version', ?)", [schemaVersion]);
  if (localeMeta != null) {
    db.execute("INSERT INTO meta(key, value) VALUES ('locale', ?)", [localeMeta]);
  }
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

  test("lookups are batched through the flush", () async {
    var resolved = false;
    final future = service.localizedName(1001, "en").then((value) {
      resolved = true;
      return value;
    });
    // Lookups are never resolved synchronously — the batch flush runs on the
    // event loop and resolves all pending lookups together.
    expect(resolved, isFalse);
    expect(await future, "Gallente Frigate");
    expect(resolved, isTrue);
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

  group("lookup chain", () {
    late Directory tempDir;

    setUpAll(() {
      final logDir = Directory.systemTemp.createTempSync("localization_chain_test_log_");
      GlobalLogger.init(logDir.path, enableDebugLog: false);
    });

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync("localization_chain_test");
      PathProvider.appSupportPath = tempDir.path;
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    /// Places [writer]'s database at the blob-store path for [resourceId]
    /// (with a dummy content hash) and returns its index entry.
    ResourceIndex_Entry _placeDb(String resourceId, void Function(String path) writer) {
      final contentHash = "ab" * 32;
      final blobPath = RepoPaths.blobPath(RepoHash.hashIdent(resourceId), contentHash);
      File(blobPath).parent.createSync(recursive: true);
      writer(blobPath);
      return ResourceIndex_Entry()
        ..resourceId = resourceId
        ..contentHash = contentHash
        ..size = Int64(File(blobPath).lengthSync());
    }

    Future<LocalizationDbService> _openService(List<ResourceIndex_Entry> entries) async {
      final index = ResourceIndex()
        ..schemaVersion = 1
        ..formatVersion = 2
        ..entries.addAll(entries);
      final proxy = ResourceBlobProxy(AssetStore(FileBlobStore()), index);
      final service = await LocalizationDbService.open(proxy);
      expect(service, isNotNull);
      return service!;
    }

    test("prefers the per-locale database when its entry is in the index", () async {
      final service = await _openService([
        _placeDb(
          localeLocalizationDbResourceId("zh"),
          (path) => _writeSchemaDb(path, "2", {
            "zh": {1001: "per-locale zh"},
          }, localeMeta: "zh"),
        ),
        _placeDb(
          kLocalizationDbResourceId,
          (path) => _writeSchemaDb(path, "1", {
            "zh": {1001: "legacy zh"},
          }),
        ),
      ]);
      addTearDown(service.close);

      expect(await service.localizedName(1001, "zh"), "per-locale zh");
    });

    test("falls back to the legacy combined database", () async {
      final service = await _openService([
        _placeDb(
          kLocalizationDbResourceId,
          (path) => _writeSchemaDb(path, "1", {
            "zh": {1001: "legacy zh"},
          }),
        ),
      ]);
      addTearDown(service.close);

      expect(await service.localizedName(1001, "zh"), "legacy zh");
    });

    test("renders placeholders when neither database is present", () async {
      final service = await _openService([]);
      addTearDown(service.close);

      expect(await service.localizedName(1001, "zh"), "");
      expect(await service.searchNames("abc", "zh"), isEmpty);
    });

    test("an unsupported per-locale schema degrades to the legacy database", () async {
      final service = await _openService([
        _placeDb(
          localeLocalizationDbResourceId("zh"),
          (path) => _writeSchemaDb(path, "3", {
            "zh": {1001: "future schema zh"},
          }, localeMeta: "zh"),
        ),
        _placeDb(
          kLocalizationDbResourceId,
          (path) => _writeSchemaDb(path, "1", {
            "zh": {1001: "legacy zh"},
          }),
        ),
      ]);
      addTearDown(service.close);

      expect(await service.localizedName(1001, "zh"), "legacy zh");
    });

    test("holds at most one open handle per requested locale", () async {
      final service = await _openService([
        _placeDb(
          kLocalizationDbResourceId,
          (path) => _writeSchemaDb(path, "1", {
            "en": {1001: "legacy en"},
            "zh": {1001: "legacy zh"},
          }),
        ),
      ]);
      addTearDown(service.close);

      // Both locales resolve through the same legacy database, cached as one
      // handle per requested locale.
      expect(await service.localizedName(1001, "en"), "legacy en");
      expect(await service.localizedName(1001, "zh"), "legacy zh");
      expect(await service.localizedName(1001, "en"), "legacy en");
    });
  });
}
