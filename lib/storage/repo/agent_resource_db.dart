import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/repo/checkout_db.dart";
import "package:eve_fit_assistant/storage/repo/checkout_db_web.dart"
    if (dart.library.io) "package:eve_fit_assistant/storage/repo/checkout_db_web_stub.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:flutter/foundation.dart" show visibleForTesting;
import "package:riverpod_annotation/riverpod_annotation.dart";
import "package:sqlite_async/sqlite_async.dart";

part "agent_resource_db.g.dart";

/// Resource id of the checkout's SQLite agent resource database.
const String kAgentResourceDbResourceId = "resource://agent/agent_resource.db";

/// Checkout database spec for the agent resource database.
const CheckoutDbSpec kAgentResourceDbSpec = CheckoutDbSpec(
  resourceId: kAgentResourceDbResourceId,
  dbNamePrefix: "agent_resource",
  supportedSchemaVersion: "1",
  label: "agent resource",
);

/// Read-only access to the active checkout's agent resource database
/// (`agent_resource.db`), backing the AI chat tools.
///
/// Carries the `type_names(locale, id, value)` table: localized type names
/// keyed by real type id, which the chat `search_items` tool resolves item
/// names against.
///
/// Unlike the localization database this is a hard dependency of the chat
/// feature: [open] throws when the resource is absent from the checkout, the
/// platform cannot host it, or its schema version is unsupported, instead of
/// degrading to empty results.
class AgentResourceDbService {
  AgentResourceDbService._(this._db);

  /// Wraps an already-open database; used by tests.
  @visibleForTesting
  AgentResourceDbService.fromDatabase(this._db);

  final SqliteDatabase _db;
  bool _closed = false;

  /// Opens the agent resource database referenced by [proxy].
  ///
  /// Throws a [StateError] when the database is unavailable or has an
  /// unsupported schema version.
  static Future<AgentResourceDbService> open(ResourceBlobProxy proxy) async {
    final SqliteDatabase db;
    try {
      final opened = await openCheckoutDb(proxy, kAgentResourceDbSpec);
      if (opened == null) {
        throw StateError("Agent resource database is unavailable ($kAgentResourceDbResourceId).");
      }
      db = opened;
    } on StateError {
      rethrow;
    } on Object catch (e, st) {
      Error.throwWithStackTrace(StateError("Failed to open agent resource database: $e"), st);
    }

    if (!await checkoutDbSchemaSupported(db, kAgentResourceDbSpec)) {
      final closeFuture = db.close();
      // Same ordering as close(): OPFS cleanup must wait for the worker to
      // release its SyncAccessHandles in the database's OPFS directory.
      registerCheckoutDbClose(closeFuture);
      await closeFuture;
      throw StateError("Agent resource database has an unsupported schema version.");
    }
    return AgentResourceDbService._(db);
  }

  /// Searches localized type names by case-insensitive substring, returning
  /// up to [limit] `type id → name` matches ordered by shortest (most
  /// specific) name first. Ids are real type ids.
  Future<Map<int, String>> searchTypeNames(String query, String locale, {int limit = 20}) async {
    if (_closed) return const {};
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const {};
    final escaped = trimmed.replaceAll(r"\", r"\\").replaceAll("%", r"\%").replaceAll("_", r"\_");
    try {
      final rows = await _db.getAll(
        "SELECT id, value FROM type_names "
        "WHERE locale = ? AND value LIKE ? ESCAPE '\\' "
        "ORDER BY LENGTH(value) ASC LIMIT ?",
        [locale, "%$escaped%", limit],
      );
      return {
        for (final row in rows)
          if (row["value"]! is String && (row["value"]! as String).isNotEmpty)
            row["id"]! as int: row["value"]! as String,
      };
    } on Object catch (e, st) {
      warning("Agent type-name search failed: $e", stackTrace: st);
      return const {};
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final closeFuture = _closeDatabase();
    // Let the web backend order OPFS cleanup (stale-database prune, storage
    // reset) behind this close: the worker may still hold SyncAccessHandles
    // inside the database's OPFS directory until it fully shuts down.
    registerCheckoutDbClose(closeFuture);
    await closeFuture;
  }

  Future<void> _closeDatabase() async {
    try {
      await _db.close();
    } on Object catch (e) {
      debug("Failed to close agent resource database: $e");
    }
  }
}

/// Agent resource database for the active checkout.
///
/// Throws while unavailable: the chat `search_items` tool depends on this
/// database, so a checkout without it (or an unsupported schema) is an error
/// surfaced to the tool caller rather than silently empty results.
@riverpodSingleton
Future<AgentResourceDbService> agentResourceDbService(Ref ref) async {
  final proxy = await ref.watch(resourceBlobProxyProvider.future);
  if (proxy == null) {
    throw StateError("No active checkout; agent resource database is unavailable.");
  }

  final service = await AgentResourceDbService.open(proxy);
  ref.onDispose(service.close);
  return service;
}
