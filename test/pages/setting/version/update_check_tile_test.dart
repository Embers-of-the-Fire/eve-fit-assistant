import "dart:async";

import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/data/proto/release_index.pb.dart";
import "package:eve_fit_assistant/pages/setting/version/update_check_tile.dart";
import "package:eve_fit_assistant/storage/repo/models/remote_app_release.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart"
    show appReleaseCheckStatusProvider, repoServiceProvider;
import "package:eve_fit_assistant/storage/repo/release_sync.dart";
import "package:eve_fit_assistant/storage/repo/service.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:mocktail/mocktail.dart";

import "../../../test_helpers.dart";

class MockRepoService extends Mock implements RepoService {}

RemoteAppRelease _release({required String releaseId, required String version}) => RemoteAppRelease(
  releaseId: releaseId,
  version: version,
  snapshotHash: "release_snapshot",
  index: ReleaseIndex(schemaVersion: 1, id: releaseId, version: version),
);

AppSetting _testAppSetting({bool remoteEnabled = false, String channel = "testing"}) => AppSetting(
  locale: Locale.zh,
  enableDebugLog: false,
  shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
  showCheckoutImpactWarnings: true,
  typeListReturnBehavior: TypeListReturnBehavior.previousPage,
  developerMode: false,
  remoteContent: RemoteContentSetting(enabled: remoteEnabled, channel: channel),
);

Widget buildTile({
  required FutureOr<ReleaseCheckStatus> Function() status,
  AppSetting? settings,
  RepoService? repoService,
}) => ProviderScope(
  overrides: [
    appReleaseCheckStatusProvider.overrideWith((_) => status()),
    appSettingServiceProvider.overrideWithValue(settings ?? _testAppSetting()),
    if (repoService != null) repoServiceProvider.overrideWith((_) => repoService),
  ],
  child: testApp(const Material(child: AppUpdateCheckTile())),
);

void main() {
  setUp(() {
    registerFallbackValue("");
  });

  group("rendering", () {
    testWidgets("busy state shows checking subtitle and spinner", (tester) async {
      final completer = Completer<ReleaseCheckStatus>();

      await tester.pumpWidget(buildTile(status: () => completer.future));
      await tester.pump();

      expect(find.text("检查更新"), findsOneWidget);
      expect(find.text("正在检查更新…"), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets("upToDate state shows subtitle and Check action", (tester) async {
      await tester.pumpWidget(buildTile(status: () => const ReleaseCheckUpToDate()));
      await tester.pump();

      expect(find.text("已是最新版本"), findsOneWidget);
      expect(find.text("检查"), findsOneWidget);
    });

    testWidgets("unavailable state shows unavailable subtitle", (tester) async {
      await tester.pumpWidget(buildTile(status: () => const ReleaseCheckUnavailable()));
      await tester.pump();

      expect(find.text("无法检查更新"), findsOneWidget);
      expect(find.text("检查"), findsOneWidget);
    });

    testWidgets("aheadOfRemote state shows warning subtitle and icon", (tester) async {
      await tester.pumpWidget(
        buildTile(status: () => const ReleaseCheckAheadOfRemote(remoteVersion: "0.9.0")),
      );
      await tester.pump();

      expect(find.text("当前版本高于最新发布版本（v0.9.0）"), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    });

    testWidgets("updateAvailable state shows release card", (tester) async {
      await tester.pumpWidget(
        buildTile(
          status: () => ReleaseCheckUpdateAvailable(
            release: _release(releaseId: "rel-2", version: "2.0.0"),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("v2.0.0 已发布"), findsOneWidget);
      expect(find.text("您也可以手动下载此更新。"), findsOneWidget);
      expect(find.byIcon(Icons.system_update_alt), findsOneWidget);
    });
  });

  group("interaction", () {
    testWidgets("tapping Check syncs the channel generation and re-checks", (tester) async {
      final mockRepoService = MockRepoService();
      when(
        () => mockRepoService.syncChannelGeneration(any()),
      ).thenAnswer((_) async => const Right(unit));

      await tester.pumpWidget(
        buildTile(
          status: () => const ReleaseCheckUpToDate(),
          settings: _testAppSetting(remoteEnabled: true),
          repoService: mockRepoService,
        ),
      );
      await tester.pump();

      await tester.tap(find.text("检查更新"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      verify(() => mockRepoService.syncChannelGeneration("testing")).called(1);
      expect(find.text("已是最新版本"), findsOneWidget);
    });

    testWidgets("failed channel sync surfaces the failure instead of checking", (tester) async {
      final mockRepoService = MockRepoService();
      when(
        () => mockRepoService.syncChannelGeneration(any()),
      ).thenAnswer((_) async => const Left("network down"));

      await tester.pumpWidget(
        buildTile(
          status: () => const ReleaseCheckUpToDate(),
          settings: _testAppSetting(remoteEnabled: true),
          repoService: mockRepoService,
        ),
      );
      await tester.pump();

      await tester.tap(find.text("检查更新"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("检查更新失败"), findsOneWidget);
      expect(find.text("重试"), findsOneWidget);
    });

    testWidgets("tile does not sync when remote content is disabled", (tester) async {
      final mockRepoService = MockRepoService();
      when(
        () => mockRepoService.syncChannelGeneration(any()),
      ).thenAnswer((_) async => const Right(unit));

      await tester.pumpWidget(
        buildTile(status: () => const ReleaseCheckUnavailable(), repoService: mockRepoService),
      );
      await tester.pump();

      await tester.tap(find.text("检查更新"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      verifyNever(() => mockRepoService.syncChannelGeneration(any()));
    });

    testWidgets("tapping while busy does not trigger a second check", (tester) async {
      final syncCompleter = Completer<Either<String, Unit>>();
      final mockRepoService = MockRepoService();
      when(
        () => mockRepoService.syncChannelGeneration(any()),
      ).thenAnswer((_) => syncCompleter.future);

      await tester.pumpWidget(
        buildTile(
          status: () => const ReleaseCheckUpToDate(),
          settings: _testAppSetting(remoteEnabled: true),
          repoService: mockRepoService,
        ),
      );
      await tester.pump();

      await tester.tap(find.text("检查更新"));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text("正在检查更新…"), findsOneWidget);

      await tester.tap(find.text("检查更新"));
      await tester.pump();

      verify(() => mockRepoService.syncChannelGeneration("testing")).called(1);

      syncCompleter.complete(const Right(unit));
      await tester.pump();
    });
  });
}
