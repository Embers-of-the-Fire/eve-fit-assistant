import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:sqlite_async/sqlite_async.dart";

/// Native stub: OPFS does not exist on native platforms; the native open path
/// in `localization_db_native.dart` is used instead.
Future<SqliteDatabase?> openWebLocalizationDb(ResourceBlobProxy proxy) =>
    throw UnsupportedError("Web localization database is unavailable on native platforms");

/// Native stub: OPFS close ordering only matters on web.
void registerLocalizationDbClose(Future<void> closeFuture) {}

/// Native stub: there are no OPFS localization copies to delete on native.
Future<void> deleteWebLocalizationDatabases() async {}
