import "dart:async";

import "package:eve_fit_assistant/compat/wasm_probe.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/fs/opfs_blob_store.dart";
import "package:eve_fit_assistant/storage/repo/checkout_db.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:sqlite3_web/sqlite3_web.dart";
import "package:sqlite_async/sqlite_async.dart";
import "package:sqlite_async/web.dart";

/// Web worker script URI for sqlite_async, bundled under `web/sqlite/`.
///
/// Note the asymmetry baked into sqlite3_web: this URI is resolved against
/// the page (hence the `sqlite/` prefix), while the wasm module URI is
/// resolved against the worker script's own location, so the wasm file stays
/// at its default `sqlite3.wasm` name and must NOT carry the prefix.
const String _kSqliteWorkerUri = "sqlite/db_worker.js";

/// Completion of the most recent checkout database close.
///
/// OPFS cleanup (stale-database prune, storage reset) must wait for the
/// previous database's worker to fully shut down: until then it may still
/// hold SyncAccessHandles inside its OPFS directory.
Future<void> _lastClose = Future.value();

/// Registers the close of a checkout database so that later OPFS cleanup
/// is ordered behind it. No-op on native (see the stub).
void registerCheckoutDbClose(Future<void> closeFuture) {
  _lastClose = _lastClose.then((_) => closeFuture, onError: (_) => closeFuture);
}

/// Deletes every OPFS copy of checkout databases, waiting for any in-flight
/// close first. Used by the web storage reset.
Future<void> deleteWebCheckoutDatabases() async {
  await _lastClose;
  await OpfsBlobStore.instance.deleteTree(kCheckoutDbOpfsRoot);
}

/// Opens the checkout database described by [spec] through sqlite_async's
/// web worker, backed by OPFS.
///
/// sqlite3_web's OPFS backend (and the SyncAccessHandle it relies on) needs a
/// cross-origin isolated origin; the deployment ships COOP/COEP headers. The
/// blob is copied once (per content hash) to the OPFS location sqlite3_web
/// expects — the database name embeds the content hash, so the OPFS path
/// uniquely identifies the content. An existing copy is validated against the
/// resource index entry's size and re-copied on mismatch, so a truncated
/// write cannot poison lookups across sessions.
///
/// Returns `null` when the origin is not cross-origin isolated, OPFS is
/// unavailable, or the resource is absent.
Future<SqliteDatabase?> openWebCheckoutDb(ResourceBlobProxy proxy, CheckoutDbSpec spec) async {
  if (!crossOriginIsolated()) {
    debug("Web is not cross-origin isolated; ${spec.label} database is unavailable.");
    return null;
  }

  final entry = proxy.entry(spec.resourceId);
  if (entry == null || entry.contentHash.isEmpty) {
    debug("${spec.label} database resource is absent from the checkout index.");
    return null;
  }

  final dbName = checkoutDbNameForHash(spec.dbNamePrefix, entry.contentHash);
  final opfs = OpfsBlobStore.instance;
  final dbFilePath = checkoutDbFilePath(dbName);

  // Probe OPFS before copying: without it sqlite3_web silently falls back to
  // IndexedDB, which would orphan the copy and open an empty database.
  try {
    await opfs.init();
  } on Object catch (e) {
    debug(
      "OPFS is unavailable despite cross-origin isolation ($e); "
      "${spec.label} database is unavailable.",
    );
    return null;
  }

  final expectedSize = entry.size.toInt();
  var existingSize = await opfs.fileSize(dbFilePath);
  if (existingSize != null && expectedSize > 0 && existingSize != expectedSize) {
    warning(
      "Cached OPFS ${spec.label} database has unexpected size"
      " ($existingSize != $expectedSize); re-copying.",
    );
    await opfs.deleteTree("$kCheckoutDbOpfsRoot/$dbName");
    existingSize = null;
  }

  if (existingSize == null) {
    final bytes = (await proxy.read(spec.resourceId)).toNullable();
    if (bytes == null) {
      debug("${spec.label} database blob could not be read; database is unavailable.");
      return null;
    }
    await opfs.write(dbFilePath, bytes);
  }
  unawaited(_lastClose.then((_) => _pruneStaleDatabases(opfs, spec, dbName)));

  return SqliteDatabase.withFactory(
    _LoggingWebSqliteOpenFactory(
      path: dbName,
      label: spec.label,
      sqliteOptions: SqliteOptions(
        // `workerUri` is page-relative; `wasmUri` stays at its default
        // `sqlite3.wasm`, which sqlite3_web resolves against the worker
        // script's location — see the note at _kSqliteWorkerUri.
        webSqliteOptions: WebSqliteOptions(
          workerUri: Uri.base.resolve(_kSqliteWorkerUri).toString(),
        ),
      ),
    ),
  );
}

/// Logs the storage mode sqlite3_web selects. A non-OPFS mode means the
/// pre-staged OPFS copy is unused and the opened database is empty, so the
/// database contents will be unavailable.
final class _LoggingWebSqliteOpenFactory extends WebSqliteOpenFactory {
  _LoggingWebSqliteOpenFactory({
    required super.path,
    required this.label,
    required super.sqliteOptions,
  });

  final String label;

  @override
  Future<ConnectToRecommendedResult> connectToWorker(WebSqlite sqlite, String name) async {
    final result = await super.connectToWorker(sqlite, name);
    if (result.implementation.storage == StorageMode.opfs) {
      debug("$label database storage: ${result.implementation.name}.");
    } else {
      warning(
        "$label database opened without OPFS (${result.implementation.name});"
        " database contents are unavailable.",
      );
    }
    return result;
  }
}

/// Best-effort cleanup of checkout databases left over from other checkouts
/// (their names all start with the spec's prefix).
Future<void> _pruneStaleDatabases(OpfsBlobStore opfs, CheckoutDbSpec spec, String keepName) async {
  try {
    final stale = <String>{};
    for (final path in await opfs.list(kCheckoutDbOpfsRoot)) {
      final segments = path.split("/");
      if (segments.length < 2) continue;
      final dir = segments[1];
      if (isStaleCheckoutDbDir(spec.dbNamePrefix, dir, keepName: keepName)) {
        stale.add("$kCheckoutDbOpfsRoot/$dir");
      }
    }
    for (final dir in stale) {
      await opfs.deleteTree(dir);
    }
  } on Object catch (e) {
    debug("Failed to prune stale ${spec.label} databases: $e");
  }
}
