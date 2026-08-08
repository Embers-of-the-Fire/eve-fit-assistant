import "dart:async";
import "dart:math" show min;

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/repo/checkout_db.dart";
import "package:eve_fit_assistant/storage/repo/localization_db_native.dart"
    if (dart.library.js_interop) "package:eve_fit_assistant/storage/repo/localization_db_native_stub.dart";
import "package:eve_fit_assistant/storage/repo/localization_db_web.dart"
    if (dart.library.io) "package:eve_fit_assistant/storage/repo/localization_db_web_stub.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:flutter/foundation.dart" show kIsWeb, visibleForTesting;
import "package:riverpod_annotation/riverpod_annotation.dart";
import "package:sqlite_async/sqlite_async.dart";

part "localization_db.g.dart";

/// Resource id of the checkout's SQLite localization database.
const String kLocalizationDbResourceId = "resource://localization/localization.db";

/// Checkout database spec for the localization database.
const CheckoutDbSpec kLocalizationDbSpec = CheckoutDbSpec(
  resourceId: kLocalizationDbResourceId,
  dbNamePrefix: "localization",
  supportedSchemaVersion: "1",
  label: "localization",
);

/// Root of the OPFS directory tree sqlite3_web uses for its databases
/// (`drift_db/<dbName>/database`).
///
/// Web-only at runtime, but declared here so the web reset path can wipe the
/// tree without importing web-only code.
const String kLocalizationDbOpfsRoot = kCheckoutDbOpfsRoot;

/// OPFS database name for the localization database copy of [contentHash].
///
/// Web-only at runtime, but pure so tests on any platform can pin the naming
/// scheme: embedding the content hash makes the OPFS path uniquely identify
/// the content.
String localizationDbNameForHash(String contentHash) =>
    checkoutDbNameForHash(kLocalizationDbSpec.dbNamePrefix, contentHash);

/// OPFS file path sqlite3_web expects for [dbName]
/// (`drift_db/<dbName>/database`).
String localizationDbFilePath(String dbName) => checkoutDbFilePath(dbName);

/// Whether [dirName] — a direct child of [kLocalizationDbOpfsRoot] — is a
/// stale localization database directory that should be pruned while [keepName]
/// is retained.
bool isStaleLocalizationDbDir(String dirName, {required String keepName}) =>
    isStaleCheckoutDbDir(kLocalizationDbSpec.dbNamePrefix, dirName, keepName: keepName);

/// Maximum ids per `IN (...)` query.
const int _kQueryChunkSize = 500;

/// Read-only access to the active checkout's localized strings.
///
/// Strings live in a prebuilt SQLite database (`localization.db`) shipped as a
/// regular checkout resource. The database is opened lazily and strings are
/// resolved on demand by primary-key lookup — nothing is decoded up front,
/// which replaces the old eager protobuf decode of every localized string at
/// startup.
///
/// Platform behavior:
/// - Native: the content-addressed blob file is opened directly, read-only.
/// - Web: the blob is copied once (per content hash) to the OPFS location
///   sqlite3_web expects, then opened through sqlite_async's web worker. Web
///   requires a cross-origin isolated origin; without one the service is
///   unavailable and name lookups degrade to empty strings.
///
/// Lookups never throw: an unavailable database or a missing entry yields an
/// empty string, and consumers render their existing placeholders.
class LocalizationDbService {
  LocalizationDbService._(this._db);

  /// Wraps an already-open database; used by tests.
  @visibleForTesting
  LocalizationDbService.fromDatabase(this._db);

  final SqliteDatabase _db;
  static const Duration _flushDebounce = Duration(milliseconds: 50);

  final Map<String, Map<int, String>> _cache = {};
  final Map<String, Map<int, Completer<String>>> _pending = {};
  Timer? _flushTimer;
  DateTime? _lastFlushAt;
  bool _closed = false;

  /// Opens the localization database referenced by [proxy].
  ///
  /// Returns `null` when the resource is absent (e.g. a checkout created
  /// before the database existed) or the platform cannot host it.
  static Future<LocalizationDbService?> open(ResourceBlobProxy proxy) async {
    try {
      final db = kIsWeb ? await _openWeb(proxy) : _openNative(proxy);
      if (db == null) return null;

      final service = LocalizationDbService._(db);
      if (!await service._schemaSupported()) {
        warning(
          "Localization database has an unsupported schema version;"
          " localized names are unavailable.",
        );
        await db.close();
        return null;
      }
      return service;
    } on Object catch (e, st) {
      warning("Failed to open localization database: $e", stackTrace: st);
      return null;
    }
  }

  static SqliteDatabase? _openNative(ResourceBlobProxy proxy) {
    final path = proxy.resolvePath(kLocalizationDbResourceId);
    if (path == null) return null;
    return openNativeLocalizationDb(path);
  }

  static Future<SqliteDatabase?> _openWeb(ResourceBlobProxy proxy) => openWebLocalizationDb(proxy);

  Future<bool> _schemaSupported() => checkoutDbSchemaSupported(_db, kLocalizationDbSpec);

  /// Resolves the localized string for [id] in [locale].
  ///
  /// Returns an empty string when the database is unavailable or the id has no
  /// entry. Lookups are batched: a fresh batch flushes on the next event-loop
  /// turn with no added latency, while a burst (e.g. scrolling) is debounced
  /// into a single query.
  Future<String> localizedName(int id, String locale) {
    final cached = _cache[locale]?[id];
    if (cached != null) return Future.value(cached);

    final pendingForLocale = _pending[locale] ??= {};
    final existing = pendingForLocale[id];
    if (existing != null) return existing.future;

    final completer = Completer<String>();
    pendingForLocale[id] = completer;
    _scheduleFlush();
    return completer.future;
  }

  /// Returns the already-resolved localized string for [id] in [locale], or
  /// `null` when it has not been resolved yet.
  ///
  /// Lets consumers synchronously render previously resolved names while a
  /// fresh lookup is in flight, instead of flashing blank.
  String? localizedNameCached(int id, String locale) => _cache[locale]?[id];

  /// Resolves many strings at once (e.g. building the text-import name index).
  ///
  /// Ids without entries are simply absent from the result.
  Future<Map<int, String>> localizedNames(Iterable<int> ids, String locale) async {
    final wanted = ids.toSet();
    if (wanted.isEmpty) return const {};

    final cache = _cache[locale] ??= {};
    final missing = wanted.where((id) => !cache.containsKey(id)).toSet();
    if (missing.isNotEmpty) {
      await _fetchIntoCache(missing, locale);
    }

    return {
      for (final id in wanted)
        if (cache[id] case final value?)
          if (value.isNotEmpty) id: value,
    };
  }

  /// Searches localized names by case-insensitive substring, returning up to
  /// [limit] `id → name` matches ordered by shortest (most specific) name
  /// first. Used by the chat fit tools to resolve item names to type ids.
  Future<Map<int, String>> searchNames(String query, String locale, {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const {};
    final escaped = trimmed.replaceAll(r"\", r"\\").replaceAll("%", r"\%").replaceAll("_", r"\_");
    try {
      final rows = await _db.getAll(
        "SELECT id, value FROM strings "
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
      warning("Localization name search failed: $e", stackTrace: st);
      return const {};
    }
  }

  /// Schedules a flush of all pending lookups.
  ///
  /// A batch that follows an idle period (e.g. a list opening) flushes on the
  /// very next event-loop turn, so names appear without an artificial delay.
  /// Lookups that keep arriving while a batch is still settling — e.g. during
  /// a scroll — are debounced, coalescing the burst into a single query
  /// instead of one per frame (the per-frame queries are what made names pop
  /// in one at a time).
  void _scheduleFlush() {
    _flushTimer?.cancel();
    final idle = _lastFlushAt == null || DateTime.now().difference(_lastFlushAt!) > _flushDebounce;
    _flushTimer = Timer(idle ? Duration.zero : _flushDebounce, _onFlushTimer);
  }

  void _onFlushTimer() {
    _flushTimer = null;
    _lastFlushAt = DateTime.now();
    unawaited(_flushPending());
  }

  Future<void> _flushPending() async {
    final locales = _pending.keys.toList();
    for (final locale in locales) {
      final pending = _pending.remove(locale);
      if (pending == null || pending.isEmpty) continue;

      await _fetchIntoCache(pending.keys.toSet(), locale);

      final cache = _cache[locale] ??= {};
      for (final entry in pending.entries) {
        entry.value.complete(cache[entry.key] ?? "");
      }
    }
  }

  Future<void> _fetchIntoCache(Set<int> ids, String locale) async {
    final cache = _cache[locale] ??= {};
    final idList = ids.toList();

    for (var start = 0; start < idList.length; start += _kQueryChunkSize) {
      final chunk = idList.sublist(start, min(start + _kQueryChunkSize, idList.length));
      final placeholders = List.filled(chunk.length, "?").join(", ");
      try {
        final rows = await _db.getAll(
          "SELECT id, value FROM strings WHERE locale = ? AND id IN ($placeholders)",
          [locale, ...chunk],
        );
        final found = <int>{};
        for (final row in rows) {
          final id = row["id"]! as int;
          cache[id] = row["value"]! as String;
          found.add(id);
        }
        // Record misses so they are never queried again — but only for ids a
        // successful query confirmed absent. A failed chunk must leave its ids
        // uncached so a transient error does not permanently blank names that
        // do have entries.
        for (final id in chunk) {
          if (!found.contains(id)) cache.putIfAbsent(id, () => "");
        }
      } on Object catch (e, st) {
        warning("Localization lookup failed for locale $locale: $e", stackTrace: st);
      }
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;

    _flushTimer?.cancel();
    _flushTimer = null;

    for (final pending in _pending.values) {
      for (final completer in pending.values) {
        if (!completer.isCompleted) completer.complete("");
      }
    }
    _pending.clear();

    final closeFuture = _closeDatabase();
    // Let the web backend order OPFS cleanup (stale-database prune, storage
    // reset) behind this close: the worker may still hold SyncAccessHandles
    // inside the database's OPFS directory until it fully shuts down.
    registerLocalizationDbClose(closeFuture);
    await closeFuture;
  }

  Future<void> _closeDatabase() async {
    try {
      await _db.close();
    } on Object catch (e) {
      debug("Failed to close localization database: $e");
    }
  }
}

/// Localization database for the active checkout, or `null` while loading /
/// when the checkout has no localization database.
@riverpodSingleton
Future<LocalizationDbService?> localizationDbService(Ref ref) async {
  final proxy = await ref.watch(resourceBlobProxyProvider.future);
  if (proxy == null) return null;

  final service = await LocalizationDbService.open(proxy);
  if (service != null) {
    ref.onDispose(service.close);
  }
  return service;
}

/// Resolves the localized string for [id] in [locale] from the active
/// checkout's localization database.
///
/// Returns an empty string while the database is loading or unavailable, or
/// when the id has no entry; consumers render their placeholders in that case.
@riverpod
Future<String> localizedName(Ref ref, {required int id, required String locale}) async {
  final service = await ref.watch(localizationDbServiceProvider.future);
  if (service == null) return "";
  return service.localizedName(id, locale);
}
