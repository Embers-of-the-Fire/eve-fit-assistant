import "dart:async";

import "package:eve_fit_assistant/compat/wasm_probe.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/fs/opfs_blob_store.dart";
import "package:eve_fit_assistant/storage/repo/localization_db.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:sqlite_async/sqlite_async.dart";
import "package:sqlite_async/web.dart";

/// Web worker script URI for sqlite_async, bundled under `web/sqlite/`.
///
/// Note the asymmetry baked into sqlite3_web: this URI is resolved against
/// the page (hence the `sqlite/` prefix), while the wasm module URI is
/// resolved against the worker script's own location, so the wasm file stays
/// at its default `sqlite3.wasm` name and must NOT carry the prefix.
const String _kSqliteWorkerUri = "sqlite/db_worker.js";

/// Opens the checkout's localization database through sqlite_async's web
/// worker, backed by OPFS.
///
/// sqlite3_web's OPFS backend (and the SyncAccessHandle it relies on) needs a
/// cross-origin isolated origin; the deployment ships COOP/COEP headers. The
/// blob is copied once (per content hash) to the OPFS location sqlite3_web
/// expects — the database name embeds the content hash, so the OPFS path
/// uniquely identifies the content and an existing file is always right.
///
/// Returns `null` when the origin is not cross-origin isolated, or the
/// resource is absent.
Future<SqliteDatabase?> openWebLocalizationDb(ResourceBlobProxy proxy) async {
  if (!crossOriginIsolated()) {
    debug("Web is not cross-origin isolated; localized names are unavailable.");
    return null;
  }

  final entry = proxy.entry(kLocalizationDbResourceId);
  if (entry == null || entry.contentHash.isEmpty) {
    debug("Localization database resource is absent from the checkout index.");
    return null;
  }

  final dbName = "localization_${entry.contentHash}";
  final opfs = OpfsBlobStore.instance;
  final dbFilePath = "drift_db/$dbName/database";

  if (!await opfs.exists(dbFilePath)) {
    final bytes = (await proxy.read(kLocalizationDbResourceId)).toNullable();
    if (bytes == null) {
      debug("Localization database blob could not be read; localized names are unavailable.");
      return null;
    }
    await opfs.write(dbFilePath, bytes);
  }
  unawaited(_pruneStaleDatabases(opfs, dbName));

  return SqliteDatabase.withFactory(
    WebSqliteOpenFactory(
      path: dbName,
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

/// Best-effort cleanup of localization databases left over from other
/// checkouts (their names all start with `localization_`).
Future<void> _pruneStaleDatabases(OpfsBlobStore opfs, String keepName) async {
  try {
    final stale = <String>{};
    for (final path in await opfs.list("drift_db")) {
      final segments = path.split("/");
      if (segments.length < 2) continue;
      final dir = segments[1];
      if (dir.startsWith("localization_") && dir != keepName) {
        stale.add("drift_db/$dir");
      }
    }
    for (final dir in stale) {
      await opfs.deleteTree(dir);
    }
  } on Object catch (e) {
    debug("Failed to prune stale localization databases: $e");
  }
}
