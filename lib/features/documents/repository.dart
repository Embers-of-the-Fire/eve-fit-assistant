import "dart:convert";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/documents/models.dart";
import "package:eve_fit_assistant/features/documents/storage.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/version.dart";
import "package:flutter/foundation.dart" show FlutterError;
import "package:flutter/services.dart" show rootBundle;
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:package_info_plus/package_info_plus.dart";

const String _bundledCatalogAssetPath = "assets/content/documents/generated/index.json";

final documentRepositoryProvider = Provider<DocumentRepository>(
  (Ref ref) => const DocumentRepository(),
);

class ReadGenerationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

final readGenerationProvider = NotifierProvider<ReadGenerationNotifier, int>(
  ReadGenerationNotifier.new,
);

final documentReadServiceProvider = Provider<DocumentReadService>(DocumentReadService.new);

class DocumentReadService {
  DocumentReadService(this._ref);

  final Ref _ref;

  bool isUnread(String documentId) => DocumentStorage.isUnread(documentId);

  void markRead(String documentId) {
    DocumentStorage.markRead(documentId);
    _ref.read(readGenerationProvider.notifier).increment();
  }

  void markAllRead(Iterable<String> ids) {
    DocumentStorage.markAllRead(ids);
    _ref.read(readGenerationProvider.notifier).increment();
  }

  void markAllUnread(Iterable<String> ids) {
    DocumentStorage.clearRead(ids);
    _ref.read(readGenerationProvider.notifier).increment();
  }

  void acknowledgeVersionBump(String version) {
    DocumentStorage.setLastSeenAppVersion(version);
    _ref.read(readGenerationProvider.notifier).increment();
  }
}

final appVersionProvider = FutureProvider<String>((Ref ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

final unreadAnnouncementCountProvider = Provider<int>((Ref ref) {
  ref.watch(readGenerationProvider);
  final feed = ref.watch(documentFeedProvider(DocumentFeedKind.announcement));
  return feed.when(
    data: (records) => records.where((r) => DocumentStorage.isUnread(r.id)).length,
    loading: () => 0,
    error: (_, _) => 0,
  );
});

final unreadVersionCountProvider = Provider<int>((Ref ref) {
  ref.watch(readGenerationProvider);
  final feed = ref.watch(documentFeedProvider(DocumentFeedKind.version));
  return feed.when(
    data: (records) => records.where((r) => DocumentStorage.isUnread(r.id)).length,
    loading: () => 0,
    error: (_, _) => 0,
  );
});

final hasVersionBumpProvider = Provider<bool>((Ref ref) {
  ref.watch(readGenerationProvider);
  final appVer = ref
      .watch(appVersionProvider)
      .when(data: (v) => v, loading: () => null, error: (_, _) => null);
  final lastSeen = DocumentStorage.lastSeenAppVersion;
  if (appVer == null || appVer == lastSeen) {
    return false;
  }
  final versionFeed = ref.watch(documentFeedProvider(DocumentFeedKind.version));
  final records = versionFeed.when(
    data: (r) => r,
    loading: () => const <DocumentRecord>[],
    error: (_, _) => const <DocumentRecord>[],
  );
  return records.any((r) => r.appVer == appVer);
});

final availableUpdateProvider = Provider<DocumentRecord?>((Ref ref) {
  ref.watch(readGenerationProvider);
  final appVer = ref
      .watch(appVersionProvider)
      .when(data: (v) => v, loading: () => null, error: (_, _) => null);
  if (appVer == null) {
    return null;
  }

  final versionFeed = ref.watch(documentFeedProvider(DocumentFeedKind.version));
  final records = versionFeed.when(
    data: (r) => r,
    loading: () => const <DocumentRecord>[],
    error: (_, _) => const <DocumentRecord>[],
  );

  final candidates = records
      .where((r) => r.appVer != null && compareVersions(r.appVer!, appVer) > 0)
      .toList();
  if (candidates.isEmpty) {
    return null;
  }

  candidates.sort((a, b) => compareVersions(b.appVer!, a.appVer!));
  final latest = candidates.first;

  if (latest.appVer == DocumentStorage.notifiedAvailableVersion) {
    return null;
  }
  return latest;
});

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

  static const Set<DocumentEntryKind> _mixedFeedKinds = <DocumentEntryKind>{
    DocumentEntryKind.announcement,
    DocumentEntryKind.information,
    DocumentEntryKind.version,
  };

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
        DocumentFeedKind.announcement => _mixedFeedKinds.contains(entry.kind),
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
          startup: entry.startup,
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
    return DocumentCatalog.fromJson(jsonDecode(text) as Map<String, dynamic>);
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
      return _stripFrontMatter(markdown);
    }
    if (entry.source == DocumentEntrySource.remote) {
      final raw = DocumentStorage.cachedBody(entry.id, localeCode) ?? localization.summary;
      return _stripFrontMatter(raw);
    }
    if (localization.bodyAssetPath case final bodyAssetPath?) {
      final raw = await _loadBundledMarkdown(
        entryId: entry.id,
        localeCode: localeCode,
        bodyAssetPath: bodyAssetPath,
        fallbackMarkdown: localization.summary,
      );
      return _stripFrontMatter(raw);
    }
    return _stripFrontMatter(localization.summary);
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

String _stripFrontMatter(String content) {
  if (!content.startsWith("---\n")) return content;
  final parts = content.split("\n---\n");
  if (parts.length < 2) return content;
  return parts.sublist(1).join("\n---\n").trimLeft();
}
