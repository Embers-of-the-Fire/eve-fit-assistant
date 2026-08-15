import "package:eve_fit_assistant/storage/repo/checkout_db.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:sqlite3/sqlite3.dart" as sqlite;
import "package:sqlite_async/native.dart";
import "package:sqlite_async/sqlite_async.dart";

/// Opens the checkout database described by [spec] through sqlite_async on
/// native platforms, or returns `null` when the resource is absent from the
/// checkout.
SqliteDatabase? openNativeCheckoutDb(ResourceBlobProxy proxy, CheckoutDbSpec spec) {
  final path = proxy.resolvePath(spec.resourceId);
  if (path == null) return null;
  return openNativeCheckoutDbFile(path);
}

/// Opens the content-addressed checkout database file at [path] through
/// sqlite_async on native platforms.
SqliteDatabase openNativeCheckoutDbFile(String path) =>
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
