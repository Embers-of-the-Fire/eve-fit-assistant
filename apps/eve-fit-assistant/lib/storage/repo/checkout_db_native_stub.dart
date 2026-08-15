import "package:eve_fit_assistant/storage/repo/checkout_db.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:sqlite_async/sqlite_async.dart";

/// Web stub: native file paths do not exist on web; the web open path in
/// `checkout_db_web.dart` is used instead.
SqliteDatabase? openNativeCheckoutDb(ResourceBlobProxy proxy, CheckoutDbSpec spec) =>
    throw UnsupportedError("Native checkout database paths are unavailable on web");

/// Web stub: native file paths do not exist on web.
SqliteDatabase openNativeCheckoutDbFile(String path) =>
    throw UnsupportedError("Native checkout database paths are unavailable on web");
