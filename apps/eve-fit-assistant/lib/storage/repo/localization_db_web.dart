import "package:eve_fit_assistant/storage/repo/checkout_db_web.dart";
import "package:eve_fit_assistant/storage/repo/localization_db.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:sqlite_async/sqlite_async.dart";

/// Opens the checkout's localization database through sqlite_async's web
/// worker, backed by OPFS. Thin wrapper over [openWebCheckoutDb]; see there
/// for the transport details.
///
/// Returns `null` when the origin is not cross-origin isolated, OPFS is
/// unavailable, or the resource is absent.
Future<SqliteDatabase?> openWebLocalizationDb(ResourceBlobProxy proxy) =>
    openWebCheckoutDb(proxy, kLocalizationDbSpec);

/// Registers the close of a localization database so that later OPFS cleanup
/// is ordered behind it. No-op on native (see the stub).
void registerLocalizationDbClose(Future<void> closeFuture) => registerCheckoutDbClose(closeFuture);

/// Deletes every OPFS copy of localization databases, waiting for any
/// in-flight close first. Used by the web storage reset.
Future<void> deleteWebLocalizationDatabases() => deleteWebCheckoutDatabases();
