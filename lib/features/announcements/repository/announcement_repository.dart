import "dart:convert";
import "dart:io" show Platform;

import "package:eve_fit_assistant/features/announcements/models/models.dart";
import "package:eve_fit_assistant/features/announcements/remote/remote.dart";
import "package:eve_fit_assistant/features/announcements/state/state.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:eve_fit_assistant/utils/version.dart";
import "package:flutter/services.dart" show rootBundle;
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:package_info_plus/package_info_plus.dart";

const String _bundledCatalogAssetPath = "assets/content/announcements/generated/catalog.json";
const String _bundledDocumentsAssetPath = "assets/content/announcements/generated/documents";

class SyncResult {
  const SyncResult({
    required this.allRecords,
    required this.versionAnnouncements,
    required this.remoteReachable,
  });

  final List<AnnouncementRecord> allRecords;
  final List<AnnouncementRecord> versionAnnouncements;
  final bool remoteReachable;
}

final announcementRepositoryProvider = Provider<AnnouncementRepository>(
  (Ref ref) => AnnouncementRepository(ref: ref),
);

class AnnouncementRepository {
  AnnouncementRepository({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Perform a full sync: fetch catalog, determine relevant pages,
  /// fetch those pages, merge with bundled catalog, return all records.
  Future<SyncResult> sync({
    required String localeCode,
    required String currentChannel,
    required String currentPlatform,
    required String installedVersion,
  }) async {
    // 1. Load bundled entries (stub for Stage 06)
    final bundledEntries = await _loadBundledEntries();

    // 2. Fetch remote catalog
    final remoteService = _ref.read(announcementRemoteServiceProvider);
    final catalog = await remoteService.fetchCatalog();

    if (catalog == null) {
      // Remote unreachable — use bundled only
      final records = <AnnouncementRecord>[];
      for (final entry in bundledEntries) {
        if (_filterEntry(entry, localeCode, currentChannel, currentPlatform, installedVersion)) {
          records.add(_buildRecord(entry, localeCode, AnnouncementEntrySource.bundled));
        }
      }
      records.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      return SyncResult(
        allRecords: records,
        versionAnnouncements: records.where((r) => r.appVersion != null).toList(),
        remoteReachable: false,
      );
    }

    // 3. Determine relevant pages
    final closedPageUuids = <String>[];
    for (final summary in catalog.pages) {
      if (summary.active) continue;
      if (compareVersions(installedVersion, summary.minAppVersion) < 0) continue;
      if (!summary.channels.contains(currentChannel)) continue;
      closedPageUuids.add(summary.uuid);
    }

    // 4. Fetch active page
    final activePage = await remoteService.fetchPage("", active: true);

    // 5. Fetch closed pages
    final remoteEntries = <AnnouncementEntry>[];
    if (activePage != null) {
      remoteEntries.addAll(activePage.entries);
    }
    for (final uuid in closedPageUuids) {
      final page = await remoteService.fetchPage(uuid);
      if (page != null) {
        remoteEntries.addAll(page.entries);
      }
    }

    // 6. Deduplicate remote entries by id (last wins)
    final remoteById = <String, AnnouncementEntry>{};
    for (final entry in remoteEntries) {
      remoteById[entry.id] = entry;
    }

    // 7. Merge bundled with remote (remote overrides bundled)
    final mergedEntries = _mergeEntries(
      bundled: bundledEntries,
      remote: remoteById.values.toList(),
    );

    // 8. Apply client-side filters
    final filtered = <AnnouncementEntry>[];
    for (final entry in mergedEntries) {
      if (_filterEntry(entry, localeCode, currentChannel, currentPlatform, installedVersion)) {
        filtered.add(entry);
      }
    }

    // 9. Sort by publishedAt desc
    filtered.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    // 10. Build records with read/dismissed state
    final remoteIds = remoteById.keys.toSet();
    final records = <AnnouncementRecord>[];
    for (final entry in filtered) {
      final source = remoteIds.contains(entry.id)
          ? AnnouncementEntrySource.remote
          : AnnouncementEntrySource.bundled;
      records.add(_buildRecord(entry, localeCode, source));
    }

    // 11. Separate version announcements
    final versionAnnouncements = records.where((r) => r.appVersion != null).toList();

    return SyncResult(
      allRecords: records,
      versionAnnouncements: versionAnnouncements,
      remoteReachable: true,
    );
  }

  /// Apply the 5-step client-side filter chain for feed eligibility (spec §9.1).
  bool _filterEntry(
    AnnouncementEntry entry,
    String localeCode,
    String currentChannel,
    String currentPlatform,
    String installedVersion,
  ) {
    // Step 1: Channel
    if (!entry.channels.contains(currentChannel)) return false;

    // Step 2: Platform
    if (!entry.platforms.contains(currentPlatform)) return false;

    // Step 3: Min version
    if (entry.minAppVersion != null &&
        compareVersions(installedVersion, entry.minAppVersion!) < 0) {
      return false;
    }

    // Step 4: Max version
    if (entry.maxAppVersion != null &&
        compareVersions(installedVersion, entry.maxAppVersion!) > 0) {
      return false;
    }

    // Step 5: Locale
    if (entry.resolveLocalization(localeCode) == null) return false;

    return true;
  }

  /// Merge bundled and remote entries, remote overrides bundled by id (spec §11.3).
  List<AnnouncementEntry> _mergeEntries({
    required List<AnnouncementEntry> bundled,
    required List<AnnouncementEntry> remote,
  }) {
    final byId = <String, AnnouncementEntry>{};
    for (final entry in bundled) {
      byId[entry.id] = entry;
    }
    for (final entry in remote) {
      byId[entry.id] = entry;
    }
    return byId.values.toList(growable: false);
  }

  /// Build an [AnnouncementRecord] from an entry, resolving locale and attaching state.
  AnnouncementRecord _buildRecord(
    AnnouncementEntry entry,
    String localeCode,
    AnnouncementEntrySource source,
  ) {
    final resolved = entry.resolveLocalization(localeCode);
    final loc = resolved?.meta;
    return AnnouncementRecord(
      id: entry.id,
      source: source,
      title: loc?.title ?? "",
      summary: loc?.summary ?? "",
      bodyHash: loc?.bodyHash ?? "",
      publishedAt: entry.publishedAt,
      localeCode: resolved?.localeCode ?? localeCode,
      tags: entry.tags,
      startup: entry.startup,
      minAppVersion: entry.minAppVersion,
      maxAppVersion: entry.maxAppVersion,
      appVersion: entry.appVersion,
      isRead: AnnouncementStateStore.isRead(entry.id),
      isDismissed: AnnouncementStateStore.isDismissed(entry.id),
    );
  }

  /// Load the announcement body for a given hash.
  /// Checks bundled assets first, then falls back to the remote body cache.
  Future<String?> fetchAnnouncementBody(String bodyHash) async {
    final bundled = await _loadBundledBody(bodyHash);
    if (bundled != null) return bundled;

    final remoteService = _ref.read(announcementRemoteServiceProvider);
    return remoteService.fetchBody(bodyHash);
  }

  Future<List<AnnouncementEntry>> _loadBundledEntries() async {
    try {
      final text = await rootBundle.loadString(_bundledCatalogAssetPath);
      final json = jsonDecode(text) as Map<String, dynamic>;

      final bundledPageJson = json["bundledPage"];
      if (bundledPageJson == null) return [];

      final page = AnnouncementPage.fromJson(bundledPageJson as Map<String, dynamic>);
      return page.entries;
    } on Object {
      return [];
    }
  }

  Future<String?> _loadBundledBody(String bodyHash) async {
    try {
      return await rootBundle.loadString("$_bundledDocumentsAssetPath/$bodyHash.md");
    } on Object {
      return null;
    }
  }
}

/// Current installed app version.
final appVersionProvider = FutureProvider<String>((Ref ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

/// The full announcement feed (sorted, filtered, merged).
final announcementFeedProvider = FutureProvider<List<AnnouncementRecord>>((Ref ref) async {
  ref.watch(announcementStateServiceProvider);
  final locale = ref.watch(localeProvider);
  final setting = ref.watch(appSettingServiceProvider);
  final repo = ref.watch(announcementRepositoryProvider);

  final version = await ref.watch(appVersionProvider.future);

  final result = await repo.sync(
    localeCode: locale.name,
    currentChannel: setting.remoteContent.channel,
    currentPlatform: Platform.operatingSystem,
    installedVersion: version,
  );

  return result.allRecords;
});

/// Version announcements (entries with appVersion != null).
final announcementVersionFeedProvider = FutureProvider<List<AnnouncementRecord>>((Ref ref) async {
  final feed = await ref.watch(announcementFeedProvider.future);
  return feed.where((r) => r.appVersion != null).toList();
});

/// Unread count for badge display.
final unreadAnnouncementCountProvider = Provider<int>((Ref ref) {
  ref.watch(announcementStateServiceProvider);
  final feed = ref.watch(announcementFeedProvider);
  return feed.when(
    data: (records) => records.where((r) => !r.isRead).length,
    loading: () => 0,
    error: (_, _) => 0,
  );
});

/// Startup announcement to show as dialog (first unread, un-dismissed,
/// startup-flagged entry).
final startupAnnouncementProvider = FutureProvider<AnnouncementRecord?>((Ref ref) async {
  ref.watch(announcementStateServiceProvider);
  final feed = await ref.watch(announcementFeedProvider.future);
  final appVer = await ref.watch(appVersionProvider.future);
  return feed.firstWhereOrNull(
    (r) =>
        r.startup &&
        !r.isRead &&
        !r.isDismissed &&
        (r.appVersion == null || compareVersions(r.appVersion!, appVer) > 0),
  );
});

/// Unread count for version entries specifically.
final unreadVersionCountProvider = Provider<int>((Ref ref) {
  ref.watch(announcementStateServiceProvider);
  final feed = ref.watch(announcementVersionFeedProvider);
  final appVer = ref
      .watch(appVersionProvider)
      .when(data: (v) => v, loading: () => null, error: (_, _) => null);
  return feed.when(
    data: (records) => records
        .where(
          (r) =>
              !r.isRead &&
              (appVer == null ||
                  r.appVersion == null ||
                  compareVersions(r.appVersion!, appVer) > 0),
        )
        .length,
    loading: () => 0,
    error: (_, _) => 0,
  );
});

/// Whether the current app version is a newly-installed bump with matching
/// version entries to show.
final hasVersionBumpProvider = Provider<bool>((Ref ref) {
  ref.watch(announcementStateServiceProvider);
  final appVer = ref
      .watch(appVersionProvider)
      .when(data: (v) => v, loading: () => null, error: (_, _) => null);
  final state = ref.read(announcementStateServiceProvider);
  final lastSeen = state.lastSeenAppVersion;
  if (appVer == null || appVer == lastSeen) {
    return false;
  }
  final versionFeed = ref.watch(announcementVersionFeedProvider);
  final records = versionFeed.when(
    data: (r) => r,
    loading: () => const <AnnouncementRecord>[],
    error: (_, _) => const <AnnouncementRecord>[],
  );
  return records.any((r) => r.appVersion == appVer);
});
