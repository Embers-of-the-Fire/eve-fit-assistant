import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/documents/models.dart";
import "package:eve_fit_assistant/features/documents/storage.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/foundation.dart" show FlutterError;
import "package:flutter/services.dart" show rootBundle;
import "package:flutter_riverpod/flutter_riverpod.dart";

const String _bundledCatalogAssetPath = "assets/content/documents/generated/index.json";

final documentRepositoryProvider = Provider<DocumentRepository>(
  (Ref ref) => const DocumentRepository(),
);

final documentFeedProvider = FutureProvider.family<List<DocumentRecord>, DocumentFeedKind>((
  Ref ref,
  DocumentFeedKind feedKind,
) async {
  final locale = ref.watch(localeProvider);
  final repository = ref.watch(documentRepositoryProvider);
  return repository.loadFeed(feedKind: feedKind, localeCode: locale.name);
});

class DocumentRepository {
  const DocumentRepository();

  Future<List<DocumentRecord>> loadFeed({
    required DocumentFeedKind feedKind,
    required String localeCode,
  }) async {
    final bundledCatalog = await _loadBundledCatalog();
    final mergedEntries = _mergeEntries(
      bundledEntries: bundledCatalog.entries,
      remoteEntries: DocumentStorage.remoteCatalog.entries,
    );

    final filteredEntries = mergedEntries.where(
      (DocumentEntry entry) => switch (feedKind) {
        DocumentFeedKind.announcement => entry.kind == DocumentEntryKind.announcement,
        DocumentFeedKind.version => entry.kind == DocumentEntryKind.version,
      },
    );

    final records = <DocumentRecord>[];
    for (final entry in filteredEntries) {
      final resolvedLocalization = entry.resolveLocalization(localeCode);
      if (resolvedLocalization == null) {
        continue;
      }
      final localization = resolvedLocalization.localization;
      final markdown = await _loadMarkdown(
        entry: entry,
        localization: localization,
        localeCode: resolvedLocalization.localeCode,
      );
      records.add(
        DocumentRecord(
          id: entry.id,
          kind: entry.kind,
          source: entry.source,
          title: localization.title,
          summary: localization.summary,
          markdown: markdown,
          publishedAt: entry.publishedAt,
          localeCode: resolvedLocalization.localeCode,
          tags: entry.tags,
          minAppVer: entry.minAppVer,
          appVer: entry.appVer,
        ),
      );
    }

    records.sort((DocumentRecord left, DocumentRecord right) {
      final publishedAtCompare = right.publishedAt.compareTo(left.publishedAt);
      if (publishedAtCompare != 0) {
        return publishedAtCompare;
      }
      return left.title.compareTo(right.title);
    });
    return records;
  }

  Future<DocumentCatalog> _loadBundledCatalog() async {
    final text = await rootBundle.loadString(_bundledCatalogAssetPath);
    return DocumentCatalog.fromJsonText(text);
  }

  List<DocumentEntry> _mergeEntries({
    required List<DocumentEntry> bundledEntries,
    required List<DocumentEntry> remoteEntries,
  }) {
    final entriesById = <String, DocumentEntry>{
      for (final entry in bundledEntries) entry.id: entry,
    };
    for (final entry in remoteEntries) {
      entriesById[entry.id] = entry;
    }
    return entriesById.values.toList(growable: false);
  }

  Future<String> _loadMarkdown({
    required DocumentEntry entry,
    required DocumentLocalization localization,
    required String localeCode,
  }) async {
    if (localization.bodyMarkdown case final markdown?) {
      return markdown;
    }
    if (entry.source == DocumentEntrySource.remote) {
      return DocumentStorage.cachedBody(entry.id, localeCode) ?? localization.summary;
    }
    if (localization.bodyAssetPath case final bodyAssetPath?) {
      return _loadBundledMarkdown(
        entryId: entry.id,
        localeCode: localeCode,
        bodyAssetPath: bodyAssetPath,
        fallbackMarkdown: localization.summary,
      );
    }
    return localization.summary;
  }

  Future<String> _loadBundledMarkdown({
    required String entryId,
    required String localeCode,
    required String bodyAssetPath,
    required String fallbackMarkdown,
  }) async {
    try {
      return await rootBundle.loadString(bodyAssetPath);
    } on FlutterError catch (exception, stackTrace) {
      warning(
        "Failed to load bundled document asset '$bodyAssetPath' for '$entryId' "
        "($localeCode): $exception; "
        "falling back to summary.",
        stackTrace: stackTrace,
      );
      return fallbackMarkdown;
    }
  }
}
