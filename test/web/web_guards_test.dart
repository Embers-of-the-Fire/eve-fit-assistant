@TestOn("browser")
library;

import "package:eve_fit_assistant/components/dialog/announcement_dialog.dart";
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/data/proto/release_index.pb.dart";
import "package:eve_fit_assistant/features/announcements/models/models.dart";
import "package:eve_fit_assistant/features/announcements/remote/remote.dart";
import "package:eve_fit_assistant/features/announcements/repository/repository.dart";
import "package:eve_fit_assistant/features/announcements/startup_announcement_gate.dart";
import "package:eve_fit_assistant/features/app_update/platform/update_platform.dart";
import "package:eve_fit_assistant/features/market_price/state/state.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";
import "package:eve_fit_assistant/features/schema_guard/migration_gate.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/pages/setting/page.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/release_sync.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";

import "../test_helpers.dart";

void main() {
  group("app update on web", () {
    test("detectAppUpdatePlatform falls back to the unsupported adapter", () {
      final adapter = detectAppUpdatePlatform();

      expect(adapter, isA<UnsupportedAppUpdateAdapter>());
      expect(adapter.supportsSelfUpdate, isFalse);
      expect(adapter.hasArtifacts(ReleaseIndex()), isFalse);
      expect(adapter.downloadTargets(ReleaseIndex()), isEmpty);
    });

    test("release check short-circuits to unavailable without network", () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final status = await container.read(appReleaseCheckStatusProvider.future);
      expect(status, isA<ReleaseCheckUnavailable>());
      expect(await container.read(remoteAppReleaseProvider.future), const None());
    });
  });

  group("market price on web", () {
    test("marketPriceServer is disabled without network", () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(marketPriceServerProvider.future), isNull);
    });
  });

  group("SettingPage version tile on web", () {
    testWidgets("hides the changelog unread badge and never reads the feed", (tester) async {
      const setting = AppSetting(
        locale: Locale.en,
        enableDebugLog: false,
        shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
        showCheckoutImpactWarnings: true,
        typeListReturnBehavior: TypeListReturnBehavior.previousPage,
        developerMode: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingServiceProvider.overrideWithValue(setting),
            // Sentinel: if the tile read the feed on web, this count would be
            // rendered as the badge.
            unreadAnnouncementCountProvider.overrideWith((_) => 99),
          ],
          child: testApp(const Material(child: SettingPage())),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // The version tile itself renders…
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      // …but no unread badge is shown and the feed count never surfaces.
      expect(find.text("99"), findsNothing);
    });
  });

  group("StartupAnnouncementGate on web", () {
    testWidgets("never surfaces the changelog queue", (tester) async {
      final record = AnnouncementRecord(
        id: "startup-1",
        source: AnnouncementEntrySource.bundled,
        title: "Release notes",
        summary: "summary",
        bodyHash: "",
        publishedAt: DateTime.utc(2026, 2),
        localeCode: "en",
        startup: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            startupAnnouncementQueueProvider.overrideWith((_) async => [record]),
          ],
          child: MaterialApp(
            home: StartupAnnouncementGate(appRouter: AppRouter(), child: const Text("child")),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("child"), findsOneWidget);
      expect(find.byType(AnnouncementDialog), findsNothing);
    });
  });

  group("announcement body cache on web", () {
    test("filesystem operations are inert no-ops", () async {
      await AnnouncementBodyCache.init();

      const hash = "abcdef12345678901234567890123456789012345678901234567890abcdef";
      await AnnouncementBodyCache.put(hash, "content");

      expect(await AnnouncementBodyCache.get(hash), isNull);
      expect(AnnouncementBodyCache.exists(hash), isFalse);
      await AnnouncementBodyCache.prune(referencedHashes: {hash});
    });
  });

  group("announcement feed on web", () {
    test("raw feed short-circuits to empty without network", () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final raw = await container.read(announcementRawFeedProvider.future);
      expect(raw.entries, isEmpty);
      expect(raw.remoteIds, isEmpty);
    });
  });

  group("dio factory on web", () {
    test("createBlobDio builds without an IO adapter", () {
      final dio = createBlobDio();
      addTearDown(dio.close);

      // Forbidden headers are omitted on web (XHR ignores them), so the
      // factory must not set them.
      expect(dio.options.headers.containsKey("User-Agent"), isFalse);
      expect(dio.options.headers.containsKey("Accept-Encoding"), isFalse);
      expect(dio.options.headers.containsKey("Connection"), isFalse);
    });
  });

  group("logger on web", () {
    test("console-only logging does not throw", () {
      GlobalLogger.init("/ignored", enableDebugLog: true);

      expect(() => debug("d"), returnsNormally);
      expect(() => info("i"), returnsNormally);
      expect(() => warning("w"), returnsNormally);
      expect(() => error("e"), returnsNormally);
      expect(() => fatal("f"), returnsNormally);
    });
  });

  group("MigrationGate on web", () {
    testWidgets("skips legacy detection and completes immediately", (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MigrationGate(onMigrationComplete: () => completed = true, theme: ThemeData()),
      );
      await tester.pump();

      expect(completed, isTrue);
    });
  });
}
