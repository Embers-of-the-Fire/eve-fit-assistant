import "dart:async";
import "dart:math" show min;

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/constant/resource_vocabulary.g.dart";
import "package:eve_fit_assistant/storage/repo/checkout_db.dart";
import "package:eve_fit_assistant/storage/repo/localization_db_web.dart"
    if (dart.library.io) "package:eve_fit_assistant/storage/repo/localization_db_web_stub.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:flutter/foundation.dart" show visibleForTesting;
import "package:riverpod_annotation/riverpod_annotation.dart";
import "package:sqlite_async/sqlite_async.dart";

part "localization_db.g.dart";

/// Resource id of the checkout's legacy combined SQLite localization
/// database.
const String kLocalizationDbResourceId = kLegacyLocalizationDbResourceId;

/// Checkout database spec for the legacy combined localization database.
const CheckoutDbSpec kLocalizationDbSpec = CheckoutDbSpec(
  resourceId: kLocalizationDbResourceId,
  dbNamePrefix: "localization",
  supportedSchemaVersion: "1",
  label: "localization",
);

/// Resource id of the per-locale localization database for [locale].
String localeLocalizationDbResourceId(String locale) =>
    kLocaleLocalizationDbResourcePattern.replaceAll(kLocalePlaceholder, locale);

/// Checkout database spec for the per-locale localization database of
/// [locale].
///
/// The OPFS name prefix (`locales_<locale>`) is deliberately disjoint from
/// the legacy prefix (`localization`): stale-directory pruning matches
/// directories by `startsWith("<prefix>_")`, so a per-locale prefix beginning
/// with the legacy prefix would be deleted by the legacy prune sweep.
CheckoutDbSpec localeLocalizationDbSpec(String locale) => CheckoutDbSpec(
  resourceId: localeLocalizationDbResourceId(locale),
  dbNamePrefix: "locales_$locale",
  supportedSchemaVersion: "2",
  label: "localization ($locale)",
);

/// OPFS database name for the per-locale database copy of [contentHash].
///
/// Web-only at runtime, but pure so tests on any platform can pin the naming
/// scheme and its disjointness from the legacy prefix.
String localeLocalizationDbNameForHash(String locale, String contentHash) =>
    checkoutDbNameForHash(localeLocalizationDbSpec(locale).dbNamePrefix, contentHash);

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
/// Strings live in prebuilt SQLite databases shipped as checkout resources:
/// one per-locale database (`localization/locales/<locale>.db`, schema "2")
/// on new snapshots, plus the legacy combined database (`localization.db`,
/// schema "1") retained indefinitely for older clients. Databases are opened
/// lazily and strings are resolved on demand by primary-key lookup — nothing
/// is decoded up front.
///
/// Each lookup resolves its database through a fixed chain (spec §4.3),
/// holding at most one open handle per requested locale:
///
/// 1. the per-locale database, when its entry is in the index;
/// 2. else the legacy combined database, when present;
/// 3. else no database — lookups yield empty strings and consumers render
///    their existing placeholders.
///
/// A per-locale database that cannot be opened (schema gate, transport
/// failure) degrades to the next chain step instead of failing. SQL text is
/// identical for both databases (both keep the `strings.locale` column).
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
  LocalizationDbService._(this._proxy) : _testDb = null;

  /// Wraps an already-open database; used by tests. Queries every locale
  /// against that database directly, bypassing the lookup chain.
  @visibleForTesting
  LocalizationDbService.fromDatabase(SqliteDatabase db) : _proxy = null, _testDb = db;

  final ResourceBlobProxy? _proxy;
  final SqliteDatabase? _testDb;
  static const Duration _flushDebounce = Duration(milliseconds: 50);

  final Map<String, Map<int, String>> _cache = {};
  final Map<String, Map<int, Completer<String>>> _pending = {};

  /// Open database handles, keyed by requested locale — at most one per
  /// locale (spec §4.3). A `null` value means the chain found no usable
  /// database for that locale.
  final Map<String, SqliteDatabase?> _handles = {};
  final Map<String, Future<SqliteDatabase?>> _pendingHandles = {};

  Timer? _flushTimer;
  DateTime? _lastFlushAt;
  bool _closed = false;

  /// Creates the localization service for the checkout behind [proxy].
  ///
  /// The service exists whenever the checkout has a resource proxy; whether
  /// any database is usable is decided per requested locale through the
  /// lookup chain, so a checkout with only per-locale databases (or none at
  /// all) still yields a service whose lookups degrade to empty strings.
  static Future<LocalizationDbService?> open(ResourceBlobProxy proxy) async =>
      LocalizationDbService._(proxy);

  /// Opens the database serving [locale] ahead of first use (best-effort).
  Future<void> warmup(String locale) async {
    await _databaseFor(locale);
  }

  /// Resolves the database handle serving [locale] through the lookup chain,
  /// opening it on first use.
  Future<SqliteDatabase?> _databaseFor(String locale) {
    final testDb = _testDb;
    if (testDb != null) return Future.value(testDb);
    if (_closed) return Future.value();
    if (_handles.containsKey(locale)) return Future.value(_handles[locale]);
    final pending = _pendingHandles[locale];
    if (pending != null) return pending;

    final future = _openForLocale(locale);
    _pendingHandles[locale] = future;
    return future;
  }

  Future<SqliteDatabase?> _openForLocale(String locale) async {
    final proxy = _proxy;
    SqliteDatabase? db;
    try {
      if (proxy != null) {
        final perLocaleSpec = localeLocalizationDbSpec(locale);
        if (proxy.entry(perLocaleSpec.resourceId) != null) {
          db = await _openChecked(proxy, perLocaleSpec);
        }
        if (db == null && proxy.entry(kLocalizationDbSpec.resourceId) != null) {
          db = await _openChecked(proxy, kLocalizationDbSpec);
        }
      }
    } on Object catch (e, st) {
      warning("Failed to open localization database for locale $locale: $e", stackTrace: st);
      db = null;
    } finally {
      _handles[locale] = db;
      _pendingHandles.remove(locale)?.ignore();
    }
    return db;
  }

  /// Opens the database described by [spec], or `null` when it cannot be
  /// hosted or its `meta.schema_version` is unsupported.
  static Future<SqliteDatabase?> _openChecked(ResourceBlobProxy proxy, CheckoutDbSpec spec) async {
    final db = await openCheckoutDb(proxy, spec);
    if (db == null) return null;
    if (!await checkoutDbSchemaSupported(db, spec)) {
      warning(
        "${spec.label} database has an unsupported schema version;"
        " localized names fall back along the lookup chain.",
      );
      final closeFuture = db.close();
      // Same ordering as close(): OPFS cleanup must wait for the worker to
      // release its SyncAccessHandles in the database's OPFS directory.
      registerLocalizationDbClose(closeFuture);
      await closeFuture;
      return null;
    }
    return db;
  }

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
    final db = await _databaseFor(locale);
    if (db == null) return const {};
    final escaped = trimmed.replaceAll(r"\", r"\\").replaceAll("%", r"\%").replaceAll("_", r"\_");
    try {
      final rows = await db.getAll(
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
    final db = await _databaseFor(locale);
    if (db == null) {
      // No database serves this locale; cache placeholders so the ids are
      // not re-queried until the service is invalidated.
      for (final id in ids) {
        cache.putIfAbsent(id, () => "");
      }
      return;
    }
    final idList = ids.toList();

    for (var start = 0; start < idList.length; start += _kQueryChunkSize) {
      final chunk = idList.sublist(start, min(start + _kQueryChunkSize, idList.length));
      final placeholders = List.filled(chunk.length, "?").join(", ");
      try {
        final rows = await db.getAll(
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
    // Wait for in-flight opens so their handles are closed too. Snapshot the
    // futures before awaiting: each open removes its locale from
    // _pendingHandles in its finally block, which would otherwise mutate the
    // live .values iterator and throw ConcurrentModificationError.
    final pending = _pendingHandles.values.toList();
    for (final future in pending) {
      await future;
    }
    _pendingHandles.clear();
    final dbs = [?_testDb, for (final db in _handles.values) ?db];
    _handles.clear();
    for (final db in dbs) {
      try {
        await db.close();
      } on Object catch (e) {
        debug("Failed to close localization database: $e");
      }
    }
  }
}

/// Localization database for the active checkout, or `null` while loading /
/// when the checkout has no resource proxy.
@riverpodSingleton
Future<LocalizationDbService?> localizationDbService(Ref ref) async {
  final proxy = await ref.watch(resourceBlobProxyProvider.future);
  if (proxy == null) return null;

  final service = await LocalizationDbService.open(proxy);
  if (service != null) {
    ref.onDispose(service.close);
    // Preserve the previous eager warm-up: open the active locale's database
    // ahead of first lookup.
    unawaited(service.warmup(ref.read(localeProvider).name));
  }
  return service;
}

/// Local availability of a locale's localization database for the active
/// checkout (spec §4.4).
sealed class LocalizationDbAvailability {
  const LocalizationDbAvailability();
}

/// The locale's database is present locally (or the legacy fallback covers
/// the locale) and ready to open.
final class LocalizationDbAvailable extends LocalizationDbAvailability {
  const LocalizationDbAvailable();
}

/// The index carries the locale's per-locale database but the blob is not
/// downloaded yet; the locale-switch dialog offers a sized download.
final class LocalizationDbDownloadable extends LocalizationDbAvailability {
  const LocalizationDbDownloadable({required this.sizeBytes});

  /// Download size of the locale's database blob, from the index entry.
  final int sizeBytes;
}

/// No per-locale entry exists in the index and no usable legacy fallback is
/// present; only a data update can bring the locale's database in.
final class LocalizationDbUpdateRequired extends LocalizationDbAvailability {
  const LocalizationDbUpdateRequired();
}

/// Availability of [locale]'s localization database for the active checkout.
///
/// A `downloadable` result means the locale-switch flow can fetch the blob on
/// demand; `updateRequired` means only a full data update can bring the
/// resource in. Old snapshots carrying only the legacy combined database are
/// **not** `updateRequired`: the §4.3 fallback covers them.
@riverpod
Future<LocalizationDbAvailability> localizationDbAvailability(Ref ref, String locale) async {
  final store = ref.watch(assetStoreProvider);
  final proxy = await ref.watch(resourceBlobProxyProvider.future);
  if (proxy == null) return const LocalizationDbUpdateRequired();

  final perLocaleId = localeLocalizationDbResourceId(locale);
  final perLocaleIdent = proxy.ident(perLocaleId);
  if (perLocaleIdent != null) {
    final exists = await store.blobExists(perLocaleIdent.identHash, perLocaleIdent.contentHash);
    if (exists) return const LocalizationDbAvailable();
    final size = proxy.entry(perLocaleId)?.size.toInt() ?? 0;
    return LocalizationDbDownloadable(sizeBytes: size);
  }

  // No per-locale entry (old snapshot): usable only when the legacy combined
  // database's blob is present.
  final legacyIdent = proxy.ident(kLocalizationDbResourceId);
  if (legacyIdent != null &&
      await store.blobExists(legacyIdent.identHash, legacyIdent.contentHash)) {
    return const LocalizationDbAvailable();
  }
  return const LocalizationDbUpdateRequired();
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
