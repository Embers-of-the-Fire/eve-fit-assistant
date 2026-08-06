import "dart:async";
import "dart:convert";

import "package:eve_fit_assistant/features/announcements/models/models.dart";
import "package:eve_fit_assistant/features/announcements/remote/remote.dart";
import "package:eve_fit_assistant/features/announcements/state/state.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_notifier.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/version.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/services.dart" show rootBundle;
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:package_info_plus/package_info_plus.dart";

const String _bundledCatalogAssetPath = "assets/content/announcements/generated/catalog.json";
const String _bundledDocumentsAssetPath = "assets/content/announcements/generated/documents";

/// Network-shaped result of a feed sync: raw entries plus the set of IDs that
/// came from the remote catalog (so callers can tag records with the right
/// source). Does NOT carry read/dismiss state — that is attached downstream
/// by [announcementFeedProvider] so local read toggles never re-run sync.
class AnnouncementRawFeed {
  const AnnouncementRawFeed({required this.entries, required this.remoteIds});

  final List<AnnouncementEntry> entries;
  final Set<String> remoteIds;
}

final announcementRepositoryProvider = Provider<AnnouncementRepository>(
  (Ref ref) => AnnouncementRepository(ref: ref),
);

class AnnouncementRepository {
  AnnouncementRepository({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Perform a full sync: fetch catalog, determine relevant pages,
  /// fetch those pages, merge with bundled catalog, return raw entries.
  ///
  /// The result is purely network-shaped — no read/dismiss state is attached,
  /// and no state pruning side effects fire here. Consumers that need
  /// [AnnouncementRecord]s with state should use [announcementFeedProvider].
  Future<AnnouncementRawFeed> sync({
    required String localeCode,
    required String currentChannel,
    required AnnouncementPlatform? currentPlatform,
    required String installedVersion,
  }) async {
    // 1. Load bundled entries.
    final bundledEntries = await _loadBundledEntries();

    // 2. Fetch remote catalog.
    final remoteService = _ref.read(announcementRemoteServiceProvider);
    final catalog = await remoteService.fetchCatalog();

    if (catalog == null) {
      // Remote unreachable — use bundled only.
      final entries = <AnnouncementEntry>[];
      for (final entry in bundledEntries) {
        if (_filterEntry(entry, localeCode, currentChannel, currentPlatform, installedVersion)) {
          entries.add(entry);
        }
      }
      entries.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      return AnnouncementRawFeed(entries: entries, remoteIds: const <String>{});
    }

    // 3. Determine relevant closed pages.
    final closedPageUuids = <String>[];
    for (final summary in catalog.pages) {
      if (summary.active) continue;
      if (compareVersions(installedVersion, summary.minAppVersion) < 0) continue;
      if (!summary.channels.contains(currentChannel)) continue;
      closedPageUuids.add(summary.uuid);
    }

    // 4. Fetch active page.
    final activePage = await remoteService.fetchPage("", active: true);

    // 5. Fetch closed pages.
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

    // 6. Deduplicate remote entries by id (last wins).
    final remoteById = <String, AnnouncementEntry>{};
    for (final entry in remoteEntries) {
      remoteById[entry.id] = entry;
    }

    // 7. Merge bundled with remote (remote overrides bundled).
    final mergedEntries = _mergeEntries(
      bundled: bundledEntries,
      remote: remoteById.values.toList(),
    );

    // 8. Apply client-side filters.
    final filtered = <AnnouncementEntry>[];
    for (final entry in mergedEntries) {
      if (_filterEntry(entry, localeCode, currentChannel, currentPlatform, installedVersion)) {
        filtered.add(entry);
      }
    }

    // 9. Sort by publishedAt desc.
    filtered.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    return AnnouncementRawFeed(entries: filtered, remoteIds: remoteById.keys.toSet());
  }

  /// Apply the 5-step client-side filter chain for feed eligibility (spec §9.1).
  bool _filterEntry(
    AnnouncementEntry entry,
    String localeCode,
    String currentChannel,
    AnnouncementPlatform? currentPlatform,
    String installedVersion,
  ) {
    // Step 1: Channel
    if (!entry.channels.contains(currentChannel)) return false;

    // Step 2: Platform (empty list = all platforms)
    if (entry.platforms.isNotEmpty && !entry.platforms.contains(currentPlatform)) return false;

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

/// Raw feed — the network layer. Depends only on inputs that change the
/// network result (locale, settings, installed version). Does NOT depend on
/// [announcementStateServiceProvider], so toggling read/dismiss state never
/// re-fires this provider.
final announcementRawFeedProvider = FutureProvider<AnnouncementRawFeed>((Ref ref) async {
  // Announcements (changelog) are not served on web; short-circuit before
  // any watch so the feed never touches network or filesystem there.
  if (kIsWeb) return const AnnouncementRawFeed(entries: [], remoteIds: {});

  final locale = ref.watch(localeProvider);
  final setting = ref.watch(appSettingServiceProvider);
  final repo = ref.watch(announcementRepositoryProvider);

  final version = await ref.watch(appVersionProvider.future);

  final raw = await repo.sync(
    localeCode: locale.name,
    currentChannel: setting.remoteContent.channel,
    currentPlatform: AnnouncementPlatform.current,
    installedVersion: version,
  );

  // Prune stale read/dismiss IDs and unused body-cache entries now that we
  // know the active set. This runs once per sync — NOT on every state toggle.
  ref
      .read(announcementStateServiceProvider.notifier)
      .pruneStaleIds(activeIds: raw.entries.map((e) => e.id).toSet());
  final referencedHashes = raw.entries
      .map((e) => e.resolveLocalization(locale.name)?.meta.bodyHash ?? "")
      .where((h) => h.isNotEmpty)
      .toSet();
  unawaited(AnnouncementBodyCache.prune(referencedHashes: referencedHashes));

  return raw;
});

/// The full announcement feed with read/dismiss state attached.
///
/// Re-runs whenever [announcementStateServiceProvider] emits (e.g. on
/// mark-read / mark-all-read), but re-uses the cached
/// [announcementRawFeedProvider] future — no network call is made on local
/// state toggles.
final announcementFeedProvider = FutureProvider<List<AnnouncementRecord>>((Ref ref) async {
  ref.watch(announcementStateServiceProvider);
  final locale = ref.watch(localeProvider);
  final raw = await ref.watch(announcementRawFeedProvider.future);
  final stateStore = ref.read(announcementStateStoreProvider);

  return raw.entries.map((entry) {
    final source = raw.remoteIds.contains(entry.id)
        ? AnnouncementEntrySource.remote
        : AnnouncementEntrySource.bundled;
    return _buildRecord(
      entry: entry,
      localeCode: locale.name,
      source: source,
      stateStore: stateStore,
    );
  }).toList();
});

/// Build an [AnnouncementRecord] from a raw entry, resolving localization and
/// attaching read/dismiss state from [stateStore].
AnnouncementRecord _buildRecord({
  required AnnouncementEntry entry,
  required String localeCode,
  required AnnouncementEntrySource source,
  required AnnouncementStateStore stateStore,
}) {
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
    isRead: stateStore.isRead(entry.id),
    isDismissed: stateStore.isDismissed(entry.id),
    entry: entry,
  );
}

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

/// Queue of startup announcements to show as dialogs, in feed order (newest
/// first). Contains all unread, un-dismissed, startup-flagged entries whose
/// `appVersion` is either absent or newer than the installed version.
final startupAnnouncementQueueProvider = FutureProvider<List<AnnouncementRecord>>((Ref ref) async {
  ref.watch(announcementStateServiceProvider);
  final feed = await ref.watch(announcementFeedProvider.future);
  final appVer = await ref.watch(appVersionProvider.future);
  return feed
      .where(
        (r) =>
            r.startup &&
            !r.isRead &&
            !r.isDismissed &&
            (r.appVersion == null || compareVersions(r.appVersion!, appVer) > 0),
      )
      .toList();
});

/// Deprecated alias returning the head of the startup queue.
@Deprecated("Use startupAnnouncementQueueProvider instead")
final startupAnnouncementProvider = FutureProvider<AnnouncementRecord?>((Ref ref) async {
  final queue = await ref.watch(startupAnnouncementQueueProvider.future);
  return queue.firstOrNull;
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
/// version entries that has not yet been acknowledged via either the APK
/// update flow or the announcement flow.
final pendingVersionBumpProvider = Provider<bool>((Ref ref) {
  ref.watch(announcementStateServiceProvider);
  final appVer = ref
      .watch(appVersionProvider)
      .when(data: (v) => v, loading: () => null, error: (_, _) => null);
  final lastSeen = ref.watch(appVersionStateServiceProvider).lastSeenAppVersion;
  if (appVer == null || appVer == lastSeen) return false;
  final feed = ref.watch(announcementVersionFeedProvider).value ?? const [];
  return feed.any((AnnouncementRecord r) => r.appVersion == appVer);
});

/// Legacy alias — kept so external consumers keep compiling during the
/// migration. Prefer [pendingVersionBumpProvider].
@Deprecated("Use pendingVersionBumpProvider instead")
final hasVersionBumpProvider = pendingVersionBumpProvider;
