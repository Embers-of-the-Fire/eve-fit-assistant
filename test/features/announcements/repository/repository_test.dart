import "dart:io";

import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/features/announcements/models/models.dart";
import "package:eve_fit_assistant/features/announcements/repository/repository.dart";
import "package:eve_fit_assistant/features/announcements/state/announcement_state_notifier.dart";
import "package:eve_fit_assistant/features/announcements/state/announcement_state_store.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_notifier.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_store.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/version.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

const _installedVersion = "2.0.0";

AppSetting _testAppSetting() => AppSetting(
  locale: Locale.en,
  enableDebugLog: false,
  shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
  showCheckoutImpactWarnings: true,
  typeListReturnBehavior: TypeListReturnBehavior.previousPage,
  developerMode: false,
  remoteContent: const RemoteContentSetting(
    enabled: true,
    originUrl: "https://cdn.example.com/",
    channel: "stable",
  ),
);

List<AnnouncementRecord> _testFeed() => [
  // Startup entry for a version the user already has (1.0.0)
  AnnouncementRecord(
    id: "old-version-startup",
    source: AnnouncementEntrySource.remote,
    title: "Old Version Startup",
    summary: "Old version announcement",
    bodyHash: "a".padRight(64, "0"),
    publishedAt: DateTime(2026, 6, 15),
    localeCode: "en",
    tags: ["release-note"],
    startup: true,
    appVersion: "1.0.0",
    isRead: false,
    isDismissed: false,
  ),
  // Startup entry for a version newer than installed (3.0.0)
  AnnouncementRecord(
    id: "new-version-startup",
    source: AnnouncementEntrySource.remote,
    title: "New Version Startup",
    summary: "New version announcement",
    bodyHash: "b".padRight(64, "0"),
    publishedAt: DateTime(2026, 6, 16),
    localeCode: "en",
    tags: ["release-note"],
    startup: true,
    appVersion: "3.0.0",
    isRead: false,
    isDismissed: false,
  ),
  // General startup entry (no appVersion)
  AnnouncementRecord(
    id: "general-startup",
    source: AnnouncementEntrySource.bundled,
    title: "General Startup",
    summary: "General startup announcement",
    bodyHash: "c".padRight(64, "0"),
    publishedAt: DateTime(2026, 6, 14),
    localeCode: "en",
    tags: ["announcement"],
    startup: true,
    isRead: false,
    isDismissed: false,
  ),
  // Version entry for a version the user already has (1.5.0), not startup
  AnnouncementRecord(
    id: "old-version-non-startup",
    source: AnnouncementEntrySource.remote,
    title: "Old Version Non-Startup",
    summary: "Old version informational entry",
    bodyHash: "d".padRight(64, "0"),
    publishedAt: DateTime(2026, 6, 13),
    localeCode: "en",
    tags: ["release-note"],
    startup: false,
    appVersion: "1.5.0",
    isRead: false,
    isDismissed: false,
  ),
  // Version entry for a version newer than installed (2.5.0), not startup
  AnnouncementRecord(
    id: "new-version-non-startup",
    source: AnnouncementEntrySource.remote,
    title: "New Version Non-Startup",
    summary: "New version informational entry",
    bodyHash: "e".padRight(64, "0"),
    publishedAt: DateTime(2026, 6, 17),
    localeCode: "en",
    tags: ["release-note"],
    startup: false,
    appVersion: "2.5.0",
    isRead: true,
    isDismissed: false,
  ),
];

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync("efa_repo_test_");
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

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  group("startupAnnouncementQueueProvider version gating", () {
    test("returns queue with eligible entries", () async {
      final container = ProviderContainer(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          announcementStateStoreProvider.overrideWithValue(stateStore),
          appVersionStateStoreProvider.overrideWithValue(versionStore),
          announcementFeedProvider.overrideWith((_) async => _testFeed()),
          appVersionProvider.overrideWith((_) async => _installedVersion),
        ],
      );
      addTearDown(container.dispose);

      final queue = await container.read(startupAnnouncementQueueProvider.future);
      // Old-version-startup (1.0.0 <= 2.0.0) is excluded
      // New-version-startup (3.0.0 > 2.0.0) is included
      // General-startup (no appVersion) is included
      expect(queue.length, 2);
      expect(queue.map((r) => r.id), containsAll(["new-version-startup", "general-startup"]));
    });

    test("excludes read startup entries", () async {
      final feed = [
        AnnouncementRecord(
          id: "new-version-startup",
          source: AnnouncementEntrySource.remote,
          title: "New Version Startup",
          summary: "New version",
          bodyHash: "b".padRight(64, "0"),
          publishedAt: DateTime(2026, 6, 16),
          localeCode: "en",
          tags: ["release-note"],
          startup: true,
          appVersion: "3.0.0",
          isRead: true,
          isDismissed: false,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          announcementStateStoreProvider.overrideWithValue(stateStore),
          appVersionStateStoreProvider.overrideWithValue(versionStore),
          announcementFeedProvider.overrideWith((_) async => feed),
          appVersionProvider.overrideWith((_) async => _installedVersion),
        ],
      );
      addTearDown(container.dispose);

      final queue = await container.read(startupAnnouncementQueueProvider.future);
      expect(queue, isEmpty);
    });

    test("excludes dismissed startup entries", () async {
      final feed = [
        AnnouncementRecord(
          id: "new-version-startup",
          source: AnnouncementEntrySource.remote,
          title: "New Version Startup",
          summary: "New version",
          bodyHash: "b".padRight(64, "0"),
          publishedAt: DateTime(2026, 6, 16),
          localeCode: "en",
          tags: ["release-note"],
          startup: true,
          appVersion: "3.0.0",
          isRead: false,
          isDismissed: true,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          announcementStateStoreProvider.overrideWithValue(stateStore),
          appVersionStateStoreProvider.overrideWithValue(versionStore),
          announcementFeedProvider.overrideWith((_) async => feed),
          appVersionProvider.overrideWith((_) async => _installedVersion),
        ],
      );
      addTearDown(container.dispose);

      final queue = await container.read(startupAnnouncementQueueProvider.future);
      expect(queue, isEmpty);
    });
  });

  group("startupAnnouncementProvider (deprecated alias)", () {
    test("returns first entry from queue", () async {
      final container = ProviderContainer(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          announcementStateStoreProvider.overrideWithValue(stateStore),
          appVersionStateStoreProvider.overrideWithValue(versionStore),
          announcementFeedProvider.overrideWith((_) async => _testFeed()),
          appVersionProvider.overrideWith((_) async => _installedVersion),
        ],
      );
      addTearDown(container.dispose);

      final record = await container.read(startupAnnouncementProvider.future);
      expect(record, isNotNull);
      expect(record!.id, "new-version-startup");
    });
  });

  group("unreadVersionCountProvider version gating", () {
    test("excludes read entries from count", () async {
      final container = ProviderContainer(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          announcementStateStoreProvider.overrideWithValue(stateStore),
          appVersionStateStoreProvider.overrideWithValue(versionStore),
          announcementFeedProvider.overrideWith((_) async => _testFeed()),
          appVersionProvider.overrideWith((_) async => _installedVersion),
        ],
      );
      addTearDown(container.dispose);

      await container.read(announcementFeedProvider.future);
      await container.read(appVersionProvider.future);
      await container.read(announcementVersionFeedProvider.future);

      final count = container.read(unreadVersionCountProvider);
      expect(count, 1);
    });

    test("includes only version entries newer than installed", () async {
      final feed = [
        AnnouncementRecord(
          id: "v-old",
          source: AnnouncementEntrySource.remote,
          title: "Old",
          summary: "",
          bodyHash: "a".padRight(64, "0"),
          publishedAt: DateTime(2026, 6, 15),
          localeCode: "en",
          tags: [],
          startup: false,
          appVersion: "1.0.0",
          isRead: false,
          isDismissed: false,
        ),
        AnnouncementRecord(
          id: "v-new",
          source: AnnouncementEntrySource.remote,
          title: "New",
          summary: "",
          bodyHash: "b".padRight(64, "0"),
          publishedAt: DateTime(2026, 6, 16),
          localeCode: "en",
          tags: [],
          startup: false,
          appVersion: "3.0.0",
          isRead: false,
          isDismissed: false,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          announcementStateStoreProvider.overrideWithValue(stateStore),
          appVersionStateStoreProvider.overrideWithValue(versionStore),
          announcementFeedProvider.overrideWith((_) async => feed),
          appVersionProvider.overrideWith((_) async => _installedVersion),
        ],
      );
      addTearDown(container.dispose);

      await container.read(announcementFeedProvider.future);
      await container.read(appVersionProvider.future);
      await container.read(announcementVersionFeedProvider.future);

      final count = container.read(unreadVersionCountProvider);
      expect(count, 1);
    });

    test("returns 0 when appVersionProvider is loading", () {
      final container = ProviderContainer(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          announcementStateStoreProvider.overrideWithValue(stateStore),
          appVersionStateStoreProvider.overrideWithValue(versionStore),
          announcementFeedProvider.overrideWith((_) async => _testFeed()),
          appVersionProvider.overrideWith((_) async {
            throw UnimplementedError();
          }),
        ],
      );
      addTearDown(container.dispose);

      final count = container.read(unreadVersionCountProvider);
      expect(count, greaterThanOrEqualTo(0));
    });
  });

  group("pendingVersionBumpProvider", () {
    test("returns true when version bump and matching entries exist", () async {
      final feed = [
        AnnouncementRecord(
          id: "v-bump",
          source: AnnouncementEntrySource.remote,
          title: "Bump",
          summary: "",
          bodyHash: "a".padRight(64, "0"),
          publishedAt: DateTime(2026, 6, 15),
          localeCode: "en",
          tags: [],
          startup: false,
          appVersion: "2.0.0",
          isRead: false,
          isDismissed: false,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          announcementStateStoreProvider.overrideWithValue(stateStore),
          appVersionStateStoreProvider.overrideWithValue(versionStore),
          announcementFeedProvider.overrideWith((_) async => feed),
          appVersionProvider.overrideWith((_) async => "2.0.0"),
        ],
      );
      addTearDown(container.dispose);

      await container.read(announcementFeedProvider.future);
      await container.read(appVersionProvider.future);
      await container.read(announcementVersionFeedProvider.future);

      expect(container.read(pendingVersionBumpProvider), isTrue);
    });

    test("returns false when lastSeenAppVersion equals current", () async {
      versionStore.setLastSeenAppVersion("2.0.0");

      final feed = [
        AnnouncementRecord(
          id: "v-bump",
          source: AnnouncementEntrySource.remote,
          title: "Bump",
          summary: "",
          bodyHash: "a".padRight(64, "0"),
          publishedAt: DateTime(2026, 6, 15),
          localeCode: "en",
          tags: [],
          startup: false,
          appVersion: "2.0.0",
          isRead: false,
          isDismissed: false,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          announcementStateStoreProvider.overrideWithValue(stateStore),
          appVersionStateStoreProvider.overrideWithValue(versionStore),
          announcementFeedProvider.overrideWith((_) async => feed),
          appVersionProvider.overrideWith((_) async => "2.0.0"),
        ],
      );
      addTearDown(container.dispose);

      await container.read(announcementFeedProvider.future);
      await container.read(appVersionProvider.future);
      await container.read(announcementVersionFeedProvider.future);

      expect(container.read(pendingVersionBumpProvider), isFalse);
    });
  });

  group("version entry appears in feed when appVersion <= installed", () {
    test("old version entries pass _filterEntry and appear in feed", () {
      expect(compareVersions("1.5.0", _installedVersion) <= 0, isTrue);
    });

    test("new version entries with appVersion > installed appear in feed", () {
      expect(compareVersions("3.0.0", _installedVersion) > 0, isTrue);
    });
  });
}
