import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/localization_db.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Searches selectable EVE types by localized name in the active locale.
///
/// Returns matching type ids ordered by relevance (shortest name first); an
/// empty or blank query yields no results.
typedef EveTypeSearcher = Future<List<int>> Function(String query, {int limit});

/// Default [EveTypeSearcher] backed by the checkout localization database.
///
/// Name search hits are localization string ids, which live in their own
/// namespace shared with group and market group names; they are mapped back
/// to type ids through [typeIdOfNameId], and ids naming anything else drop
/// out. Picker-specific restrictions (slot compatibility, published flags,
/// meta filter) stay with the caller.
class LocalizationTypeSearcher {
  const LocalizationTypeSearcher({
    required this.localizationDb,
    required this.locale,
    required this.typeIdOfNameId,
  });

  /// Builds a searcher bound to the active checkout and locale via [ref].
  ///
  /// All inputs are read lazily per search so a picker opened before the
  /// localization database finishes loading still searches correctly later.
  factory LocalizationTypeSearcher.fromRef(WidgetRef ref) => LocalizationTypeSearcher(
    localizationDb: () => ref.read(localizationDbServiceProvider.future),
    locale: () => ref.read(localeProvider).name,
    typeIdOfNameId: (nameId) => ref.read(repoCollectionProvider)?.getTypeIdByNameId(nameId),
  );

  final Future<LocalizationDbService?> Function() localizationDb;
  final String Function() locale;

  /// Maps a localization string id to the type whose name it carries.
  final int? Function(int nameId) typeIdOfNameId;

  /// Hits include non-type name ids that are dropped afterwards, so the query
  /// over-fetches to still surface up to the requested number of results.
  static const int _overFetchFactor = 4;

  /// Implements [EveTypeSearcher].
  Future<List<int>> search(String query, {int limit = 50}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    // Localization database initialization may fail (e.g. a broken checkout);
    // fall back to the empty result instead of throwing through the picker.
    final LocalizationDbService? db;
    try {
      db = await localizationDb();
    } on Object {
      return const [];
    }
    if (db == null) return const [];
    final hits = await db.searchNames(trimmed, locale(), limit: limit * _overFetchFactor);
    return hits.keys.map(typeIdOfNameId).nonNulls.take(limit).toList();
  }
}
