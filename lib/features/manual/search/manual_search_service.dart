import "dart:io";

import "package:crypto/crypto.dart";
import "package:eve_fit_assistant/features/manual/search/manual_search_text.dart";
import "package:flutter/services.dart" show rootBundle;
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:sqlite3/sqlite3.dart" show ResultSet;
import "package:sqlite_async/sqlite_async.dart";

const String _searchDbAssetPath = "assets/content/manual/generated/manual_search.db";
const int _maxResults = 20;

/// A single manual search hit.
class ManualSearchResult {
  const ManualSearchResult({
    required this.docId,
    required this.title,
    required this.titleRanges,
    required this.snippet,
  });

  /// Path-joined doc id, e.g. `fitting/modules`.
  final String docId;

  /// Localized doc title (indexed, normalized text).
  final String title;

  /// Highlight ranges within [title].
  final List<MatchRange> titleRanges;

  /// Body snippet with highlight ranges.
  final SearchSnippet snippet;
}

/// Queries the prebuilt FTS5 manual search index bundled as an asset.
///
/// The database file is copied from assets into the application support
/// directory on first use (SQLite requires a real file path); the copied file
/// name embeds the asset content hash so app updates invalidate stale copies.
class ManualSearchService {
  /// Wrap an already-open database; used by tests.
  ManualSearchService.fromDatabase(this._db);
  ManualSearchService._(this._db);

  final SqliteDatabase _db;

  /// Open the search index from the bundled asset.
  static Future<ManualSearchService> fromAsset() async {
    final data = await rootBundle.load(_searchDbAssetPath);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    final supportDir = await getApplicationSupportDirectory();
    final hash = sha256.convert(bytes).toString().substring(0, 16);
    final file = File(p.join(supportDir.path, "manual_search_$hash.db"));
    if (!file.existsSync()) {
      await file.writeAsBytes(bytes, flush: true);
    }

    return ManualSearchService._(SqliteDatabase(path: file.path));
  }

  Future<void> close() => _db.close();

  /// Search the manual in [localeCode] (`zh` uses trigram substring matching,
  /// everything else falls back to the English porter index), returning at
  /// most [_maxResults] hits ordered by relevance.
  Future<List<ManualSearchResult>> search(String query, String localeCode) async {
    final normalized = normalizeSearchText(query);
    if (normalized.isEmpty) return const [];

    final language = localeCode.replaceAll("-", "_").split("_").first.toLowerCase();
    final rows = switch (language) {
      "zh" => await _searchZh(normalized),
      _ => await _searchEn(normalized),
    };
    if (rows == null) return const [];

    return [
      for (final row in rows)
        ManualSearchResult(
          docId: row["doc_id"]! as String,
          title: row["title"]! as String,
          titleRanges: titleMatchRanges(row["title"]! as String, normalized),
          snippet: extractSnippet(row["body"]! as String, normalized),
        ),
    ];
  }

  Future<ResultSet> _searchZh(String normalized) {
    if (normalized.runes.length >= trigramMinQueryLength) {
      return _db.getAll(
        "SELECT doc_id, title, body FROM manual_fts_zh"
        " WHERE manual_fts_zh MATCH ?"
        " ORDER BY bm25(manual_fts_zh, 0.0, 10.0, 1.0)"
        " LIMIT ?",
        [buildTrigramMatchQuery(normalized), _maxResults],
      );
    }
    final pattern = "%${normalized.replaceAll("%", "").replaceAll("_", "")}%";
    return _db.getAll(
      "SELECT doc_id, title, body FROM manual_fts_zh"
      " WHERE title LIKE ? OR body LIKE ?"
      " ORDER BY (title LIKE ?) DESC"
      " LIMIT ?",
      [pattern, pattern, pattern, _maxResults],
    );
  }

  /// Returns `null` when the query contains no indexable term.
  Future<ResultSet?> _searchEn(String normalized) {
    final match = buildPorterMatchQuery(normalized);
    if (match.isEmpty) return Future.value();
    return _db.getAll(
      "SELECT doc_id, title, body FROM manual_fts_en"
      " WHERE manual_fts_en MATCH ?"
      " ORDER BY bm25(manual_fts_en, 0.0, 10.0, 1.0)"
      " LIMIT ?",
      [match, _maxResults],
    );
  }
}

/// The lazily-opened manual search service.
final manualSearchServiceProvider = FutureProvider<ManualSearchService>((Ref ref) async {
  final service = await ManualSearchService.fromAsset();
  ref.onDispose(service.close);
  return service;
});
