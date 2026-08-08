import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/constant/eve.dart";
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
  supportedSchemaVersion: "2",
  label: "agent resource",
);

/// Item-kind filter for [AgentResourceDbService.searchTypes], mirroring the
/// `kind` parameter of the chat `search_items` tool.
enum AgentSearchKind {
  ship,
  module,
  charge,
  drone,
  fighter,

  /// Implants and boosters share category 20; they are told apart by the
  /// `slot_kind` column (`implant` = dogma attribute 331 present).
  implant,

  /// See [AgentSearchKind.implant]; `slot_kind` = `booster` (attribute 1087).
  booster;

  /// Parses the raw `kind` string from the chat tool call, or `null` when
  /// the value is not a known kind.
  static AgentSearchKind? parse(String raw) => switch (raw.trim().toLowerCase()) {
    "ship" => AgentSearchKind.ship,
    "module" => AgentSearchKind.module,
    "charge" => AgentSearchKind.charge,
    "drone" => AgentSearchKind.drone,
    "fighter" => AgentSearchKind.fighter,
    "implant" => AgentSearchKind.implant,
    "booster" => AgentSearchKind.booster,
    _ => null,
  };

  /// SQL fragment restricting the `type_names` query to this kind.
  String get whereClause => switch (this) {
    AgentSearchKind.ship => "category_id = ${EveConstCategoryId.ship}",
    AgentSearchKind.module => "category_id = ${EveConstCategoryId.module}",
    AgentSearchKind.charge => "category_id = ${EveConstCategoryId.charge}",
    AgentSearchKind.drone => "category_id = ${EveConstCategoryId.drone}",
    AgentSearchKind.fighter => "category_id = ${EveConstCategoryId.fighter}",
    AgentSearchKind.implant => "slot_kind = 'implant'",
    AgentSearchKind.booster => "slot_kind = 'booster'",
  };
}

/// One `search_items` hit: a localized type name plus the structural
/// metadata carried by the schema-v2 `type_names` table.
class AgentTypeSearchHit {
  const AgentTypeSearchHit({
    required this.typeId,
    required this.name,
    required this.groupId,
    required this.categoryId,
    this.slotIndex,
    this.slotKind,
  });

  final int typeId;
  final String name;
  final int? groupId;
  final int? categoryId;

  /// Implant/booster slot (dogma attributes 331/1087); only set for those.
  final int? slotIndex;

  /// `implant` or `booster` for slot-bearing types, else `null`.
  final String? slotKind;
}

/// Read-only access to the active checkout's agent resource database
/// (`agent_resource.db`), backing the AI chat tools.
///
/// Carries the `type_names` table: localized type names keyed by real type
/// id plus structural metadata (group/category ids, implant/booster slot),
/// which the chat `search_items` tool resolves item names against.
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
  /// up to [limit] matches ordered by shortest (most specific) name first.
  /// Ids are real type ids. [kind] restricts results to one item kind.
  Future<List<AgentTypeSearchHit>> searchTypes(
    String query,
    String locale, {
    AgentSearchKind? kind,
    int limit = 20,
  }) async {
    if (_closed) return const [];
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final escaped = trimmed.replaceAll(r"\", r"\\").replaceAll("%", r"\%").replaceAll("_", r"\_");
    try {
      final rows = await _db.getAll(
        "SELECT id, value, group_id, category_id, slot_index, slot_kind FROM type_names "
        "WHERE locale = ? AND value LIKE ? ESCAPE '\\' "
        "${kind == null ? "" : "AND ${kind.whereClause} "}"
        "ORDER BY LENGTH(value) ASC LIMIT ?",
        [locale, "%$escaped%", limit],
      );
      return [
        for (final row in rows)
          if (row["value"]! is String && (row["value"]! as String).isNotEmpty)
            AgentTypeSearchHit(
              typeId: row["id"]! as int,
              name: row["value"]! as String,
              groupId: row["group_id"] as int?,
              categoryId: row["category_id"] as int?,
              slotIndex: row["slot_index"] as int?,
              slotKind: row["slot_kind"] as String?,
            ),
      ];
    } on Object catch (e, st) {
      warning("Agent type-name search failed: $e", stackTrace: st);
      return const [];
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

/// Local availability of the agent resource database for the active checkout.
enum AgentDbAvailability {
  /// The blob is present locally and ready to open.
  available,

  /// The index carries the resource but the blob is not downloaded yet.
  downloadable,

  /// The active checkout's index predates the agent resource; a data update
  /// is required.
  updateRequired,
}

/// Availability of the agent resource database for the active checkout.
///
/// Assumes an active checkout exists (callers gate on that first). A
/// `downloadable` result means the AI gate can fetch the blob on demand;
/// `updateRequired` means only a full data update can bring the resource in.
@riverpod
Future<AgentDbAvailability> agentDbAvailability(Ref ref) async {
  final proxy = await ref.watch(resourceBlobProxyProvider.future);
  if (proxy == null) return AgentDbAvailability.updateRequired;

  final ident = proxy.ident(kAgentResourceDbResourceId);
  if (ident == null) return AgentDbAvailability.updateRequired;

  final store = ref.watch(assetStoreProvider);
  final exists = await store.blobExists(ident.identHash, ident.contentHash);
  return exists ? AgentDbAvailability.available : AgentDbAvailability.downloadable;
}
