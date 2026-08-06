import "package:sqlite3/sqlite3.dart" as sqlite;
import "package:sqlite_async/native.dart";
import "package:sqlite_async/sqlite_async.dart";

/// Opens the content-addressed localization database file at [path] through
/// sqlite_async on native platforms.
SqliteDatabase openNativeLocalizationDb(String path) =>
    SqliteDatabase.withFactory(ReadOnlyBlobDbFactory(path: path));

/// Opens content-addressed blob database files strictly read-only.
///
/// The default [SqliteDatabase] pool opens a writable primary connection and
/// switches it to WAL, which would create `-wal`/`-shm` siblings inside the
/// immutable blob store. Blob databases are never written, so every
/// connection is forced to read-only and no pragmas are applied.
final class ReadOnlyBlobDbFactory extends NativeSqliteOpenFactory {
  ReadOnlyBlobDbFactory({required super.path})
    : super(
        sqliteOptions: const SqliteOptions(
          journalMode: null,
          journalSizeLimit: null,
          synchronous: null,
        ),
      );

  @override
  List<String> pragmaStatements(SqliteOpenOptions options) => const [];

  @override
  sqlite.Database openNativeConnection(SqliteOpenOptions options) =>
      sqlite.sqlite3.open(path, mode: sqlite.OpenMode.readOnly, mutex: false);
}
