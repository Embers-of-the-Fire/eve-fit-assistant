import "package:eve_fit_assistant/storage/repo/checkout_db.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:sqlite_async/sqlite_async.dart";

/// Native stub: OPFS does not exist on native platforms; the native open path
/// in `checkout_db_native.dart` is used instead.
Future<SqliteDatabase?> openWebCheckoutDb(ResourceBlobProxy proxy, CheckoutDbSpec spec) =>
    throw UnsupportedError("Web checkout database is unavailable on native platforms");

/// Native stub: OPFS close ordering only matters on web.
void registerCheckoutDbClose(Future<void> closeFuture) {}

/// Native stub: there are no OPFS checkout database copies to delete on
/// native.
Future<void> deleteWebCheckoutDatabases() async {}
