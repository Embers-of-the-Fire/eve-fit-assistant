import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/repo/checkout_db_native.dart"
    if (dart.library.js_interop) "package:eve_fit_assistant/storage/repo/checkout_db_native_stub.dart";
import "package:eve_fit_assistant/storage/repo/checkout_db_web.dart"
    if (dart.library.io) "package:eve_fit_assistant/storage/repo/checkout_db_web_stub.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:sqlite_async/sqlite_async.dart";

/// Describes a prebuilt SQLite database shipped as a checkout resource
/// (e.g. `localization.db`, `agent_resource.db`).
///
/// All checkout databases share the same transport: content-addressed blob,
/// opened read-only on native, copied per content hash into OPFS and opened
/// through sqlite_async's web worker on web. Each carries a
/// `meta(key='schema_version')` row clients match against
/// [supportedSchemaVersion].
class CheckoutDbSpec {
  const CheckoutDbSpec({
    required this.resourceId,
    required this.dbNamePrefix,
    required this.supportedSchemaVersion,
    required this.label,
  });

  /// Resource id of the database blob (`resource://...`).
  final String resourceId;

  /// OPFS database name prefix; the content hash is appended to form the
  /// database name, so the OPFS path uniquely identifies the content.
  final String dbNamePrefix;

  /// Value of `meta.schema_version` this client understands.
  final String supportedSchemaVersion;

  /// Human-readable name used in log messages (e.g. "localization").
  final String label;
}

/// Root of the OPFS directory tree sqlite3_web uses for checkout databases
/// (`drift_db/<dbName>/database`).
///
/// Web-only at runtime, but declared here so the web reset path can wipe the
/// tree without importing web-only code.
const String kCheckoutDbOpfsRoot = "drift_db";

/// OPFS database name for the checkout database copy of [contentHash].
///
/// Web-only at runtime, but pure so tests on any platform can pin the naming
/// scheme: embedding the content hash makes the OPFS path uniquely identify
/// the content.
String checkoutDbNameForHash(String dbNamePrefix, String contentHash) =>
    "${dbNamePrefix}_$contentHash";

/// OPFS file path sqlite3_web expects for [dbName]
/// (`drift_db/<dbName>/database`).
String checkoutDbFilePath(String dbName) => "$kCheckoutDbOpfsRoot/$dbName/database";

/// Whether [dirName] — a direct child of [kCheckoutDbOpfsRoot] — is a stale
/// checkout database directory with prefix [dbNamePrefix] that should be
/// pruned while [keepName] is retained.
bool isStaleCheckoutDbDir(String dbNamePrefix, String dirName, {required String keepName}) =>
    dirName.startsWith("${dbNamePrefix}_") && dirName != keepName;

/// Opens the checkout database described by [spec], or `null` when the
/// resource is absent from the checkout or the platform cannot host it
/// (e.g. web without cross-origin isolation).
Future<SqliteDatabase?> openCheckoutDb(ResourceBlobProxy proxy, CheckoutDbSpec spec) =>
    kIsWeb ? openWebCheckoutDb(proxy, spec) : Future.value(openNativeCheckoutDb(proxy, spec));

/// Whether [db] carries a `meta.schema_version` row matching
/// [CheckoutDbSpec.supportedSchemaVersion].
Future<bool> checkoutDbSchemaSupported(SqliteDatabase db, CheckoutDbSpec spec) async {
  try {
    final row = await db.getOptional("SELECT value FROM meta WHERE key = 'schema_version'");
    return row?["value"] == spec.supportedSchemaVersion;
  } on Object catch (e, st) {
    warning("${spec.label} database schema check failed: $e", stackTrace: st);
    return false;
  }
}
