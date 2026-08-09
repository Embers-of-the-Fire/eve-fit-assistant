import "package:eve_fit_assistant/storage/repo/checkout_db_native.dart";
import "package:sqlite_async/sqlite_async.dart";

export "package:eve_fit_assistant/storage/repo/checkout_db_native.dart" show ReadOnlyBlobDbFactory;

/// Opens the content-addressed localization database file at [path] through
/// sqlite_async on native platforms.
SqliteDatabase openNativeLocalizationDb(String path) => openNativeCheckoutDbFile(path);
