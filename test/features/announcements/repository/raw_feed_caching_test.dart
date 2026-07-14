import "dart:async";
import "dart:io";

import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/features/announcements/models/models.dart";
import "package:eve_fit_assistant/features/announcements/remote/remote.dart";
import "package:eve_fit_assistant/features/announcements/repository/repository.dart";
import "package:eve_fit_assistant/features/announcements/state/announcement_state_notifier.dart";
import "package:eve_fit_assistant/features/announcements/state/announcement_state_store.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_notifier.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_store.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

const _installedVersion = "2.0.0";

/// Repository that counts how many times [sync] is invoked. Used to detect
/// accidental re-fetches when only local read/dismiss state changes.
class _CountingRepository extends AnnouncementRepository {
  _CountingRepository({required super.ref, required this.feed});

  final AnnouncementRawFeed feed;
  int syncCount = 0;

  @override
  Future<AnnouncementRawFeed> sync({
    required String localeCode,
    required String currentChannel,
    required String currentPlatform,
    required String installedVersion,
  }) async {
    syncCount += 1;
    return feed;
  }
}

AppSetting _testAppSetting() => const AppSetting(
  locale: Locale.en,
  enableDebugLog: false,
  shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
  showCheckoutImpactWarnings: true,
  typeListReturnBehavior: TypeListReturnBehavior.previousPage,
  developerMode: false,
  remoteContent: RemoteContentSetting(originUrl: "https://cdn.example.com/", channel: "stable"),
);

AnnouncementEntry _entry(String id) => AnnouncementEntry(
  id: id,
  publishedAt: DateTime(2026, 6, 15),
  channels: const ["stable"],
  platforms: const ["android"],
  localizations: const {"en": LocalizationMeta(title: "Title", summary: "Summary", bodyHash: "")},
);

/// Test harness that keeps a long-lived subscription to
/// [announcementFeedProvider] and lets tests wait for the next `AsyncData`
/// emission after a state or refresh action.
class _FeedHarness {
  _FeedHarness(this.container) {
    _sub = container.listen(announcementFeedProvider, (prev, next) {
      _states.add(next);
      final waiter = _waiter;
      if (waiter != null && next is AsyncData<List<AnnouncementRecord>>) {
        _waiter = null;
        waiter.complete(next.value);
      }
    });
  }

  final ProviderContainer container;
  late final ProviderSubscription<AsyncValue<List<AnnouncementRecord>>> _sub;
  final List<AsyncValue<List<AnnouncementRecord>>> _states = [];
  Completer<List<AnnouncementRecord>>? _waiter;

  /// Trigger the initial evaluation of the feed provider.
  void start() {
    container.read(announcementFeedProvider);
  }

  /// Wait for the next `AsyncData` emission after this call. If the provider
  /// already holds `AsyncData` and no further emission occurs (i.e. the
  /// action is a no-op), this times out.
  Future<List<AnnouncementRecord>> nextData() {
    final completer = Completer<List<AnnouncementRecord>>();
    _waiter = completer;
    // If the provider is currently loading, that loading emission may have
    // already fired before we registered the waiter. Re-check the current
    // state and, if it is already data AND the data is fresh (i.e. the last
    // emission is data and was emitted after this call), complete eagerly.
    return completer.future.timeout(const Duration(seconds: 5));
  }

  void dispose() {
    _sub.close();
  }
}

void main() {
  late Directory tempDir;

  setUp(() {
    // Per-test tempDir so on-disk state does not leak between tests.
    tempDir = Directory.systemTemp.createTempSync("efa_raw_feed_test_");
    PathProvider.documentsPath = tempDir.path;
    PathProvider.tempPath = tempDir.path;
    PathProvider.appSupportPath = tempDir.path;
    PathProvider.cachesPath = tempDir.path;
  });

  late AnnouncementStateStore stateStore;
  late AppVersionStateStore versionStore;

  setUp(() async {
    stateStore = AnnouncementStateStore(settingsPath: tempDir.path);
    await stateStore.init();
    versionStore = AppVersionStateStore(settingsPath: tempDir.path);
    await versionStore.init();
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  ProviderContainer buildContainer(
    AnnouncementRawFeed rawFeed,
    void Function(_CountingRepository) capture,
  ) => ProviderContainer(
    overrides: [
      appSettingServiceProvider.overrideWithValue(_testAppSetting()),
      announcementStateStoreProvider.overrideWithValue(stateStore),
      appVersionStateStoreProvider.overrideWithValue(versionStore),
      appVersionProvider.overrideWith((_) async => _installedVersion),
      announcementRepositoryProvider.overrideWith((ref) {
        final repo = _CountingRepository(ref: ref, feed: rawFeed);
        capture(repo);
        return repo;
      }),
    ],
  );

  group("announcementRawFeedProvider / announcementFeedProvider split", () {
    test("mark-all-read re-derives in-memory only — no second sync", () async {
      final rawFeed = AnnouncementRawFeed(
        entries: [_entry("a"), _entry("b"), _entry("c")],
        remoteIds: {"a", "b", "c"},
      );
      late _CountingRepository countingRepo;
      final container = buildContainer(rawFeed, (r) => countingRepo = r);
      addTearDown(container.dispose);

      final harness = _FeedHarness(container);
      addTearDown(harness.dispose);
      harness.start();

      final initial = await harness.nextData();
      expect(initial.length, 3);
      expect(initial.every((r) => !r.isRead), isTrue);
      expect(countingRepo.syncCount, 1);

      container
          .read(announcementStateServiceProvider.notifier)
          .markAllRead(initial.map((r) => r.id));

      final updated = await harness.nextData();
      expect(updated.every((r) => r.isRead), isTrue);
      expect(countingRepo.syncCount, 1, reason: "state toggle must not re-run sync");
    });

    test("mark-unread re-derives in-memory only — no second sync", () async {
      final rawFeed = AnnouncementRawFeed(
        entries: [_entry("a"), _entry("b")],
        remoteIds: {"a", "b"},
      );
      late _CountingRepository countingRepo;
      final container = buildContainer(rawFeed, (r) => countingRepo = r);
      addTearDown(container.dispose);

      final harness = _FeedHarness(container);
      addTearDown(harness.dispose);
      harness.start();

      final initial = await harness.nextData();
      expect(initial.every((r) => !r.isRead), isTrue);
      expect(countingRepo.syncCount, 1);

      container
          .read(announcementStateServiceProvider.notifier)
          .markAllRead(initial.map((r) => r.id));
      final markedRead = await harness.nextData();
      expect(markedRead.every((r) => r.isRead), isTrue);

      container
          .read(announcementStateServiceProvider.notifier)
          .markUnread(markedRead.map((r) => r.id));
      final markedUnread = await harness.nextData();
      expect(markedUnread.every((r) => !r.isRead), isTrue);
      expect(countingRepo.syncCount, 1, reason: "mark-unread must not re-run sync");
    });

    test(
      "remote-cache invalidation + raw-provider invalidation triggers exactly one additional sync",
      () async {
        final rawFeed = AnnouncementRawFeed(entries: [_entry("a")], remoteIds: {"a"});
        late _CountingRepository countingRepo;
        final container = buildContainer(rawFeed, (r) => countingRepo = r);
        addTearDown(container.dispose);

        final harness = _FeedHarness(container);
        addTearDown(harness.dispose);
        harness.start();

        await harness.nextData();
        expect(countingRepo.syncCount, 1);

        // Mirror what _refreshFeed does in feed_page.dart.
        container.read(announcementRemoteServiceProvider).invalidateCache();
        container.invalidate(announcementRawFeedProvider);

        await harness.nextData();
        expect(countingRepo.syncCount, 2, reason: "explicit refresh must re-run sync once");
      },
    );
  });
}
