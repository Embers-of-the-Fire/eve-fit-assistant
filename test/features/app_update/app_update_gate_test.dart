@TestOn("vm")
library;

import "dart:io";

import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/data/proto/release_index.pb.dart";
import "package:eve_fit_assistant/features/announcements/repository/announcement_repository.dart"
    show appVersionProvider;
import "package:eve_fit_assistant/features/app_update/app_update_gate.dart";
import "package:eve_fit_assistant/features/app_update/app_update_service.dart";
import "package:eve_fit_assistant/features/app_update/app_update_status.dart";
import "package:eve_fit_assistant/features/app_update/platform/manual_download_dialog.dart";
import "package:eve_fit_assistant/features/app_update/platform/update_platform.dart";
import "package:eve_fit_assistant/features/app_update/providers.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_notifier.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_store.dart";
import "package:eve_fit_assistant/storage/repo/models/remote_app_release.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart" show availableAppReleaseProvider;
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fixnum/fixnum.dart";
import "package:fpdart/fpdart.dart";

import "../../test_helpers.dart";

class _FakeAppUpdateController extends AppUpdateController {
  _FakeAppUpdateController({required this.statusAfterDownload});

  final AppUpdateStatus statusAfterDownload;

  var downloadCalls = 0;
  var installCalls = 0;

  @override
  AppUpdateStatus build(RemoteAppRelease release) => const AppUpdateStatus.idle();

  @override
  Future<void> download() async {
    downloadCalls += 1;
    state = const AppUpdateStatus.downloading(receivedBytes: 0, totalBytes: 100);
    state = statusAfterDownload;
  }

  @override
  Future<void> install() async {
    installCalls += 1;
    // Mirror the real controller: installing, then back to readyToInstall.
    // The readyToInstall emission re-enters the silent status listener while
    // the confirmation flow is still in flight.
    state = const AppUpdateStatus.installing();
    state = const AppUpdateStatus.readyToInstall(apkPath: "/tmp/update.apk");
  }
}

RemoteAppRelease _release({String releaseId = "rel-2", String version = "2.0.0"}) =>
    RemoteAppRelease(
      releaseId: releaseId,
      version: version,
      snapshotHash: "release_snapshot",
      index: ReleaseIndex(
        schemaVersion: 1,
        id: releaseId,
        version: version,
        android: AndroidArtifacts(
          general: AndroidArtifactVariant(
            identifier: "ident/general",
            contentHash: "hash",
            size: Int64(100),
          ),
        ),
        linux: LinuxArtifacts(
          appimage: LinuxArtifactVariant(
            identifier: "ident/appimage",
            contentHash: "hash-appimage",
            size: Int64(200),
          ),
          native: LinuxArtifactVariant(
            identifier: "ident/native",
            contentHash: "hash-native",
            size: Int64(300),
          ),
        ),
      ),
    );

const _androidArtifact = AppUpdateArtifact(
  variant: "general",
  identifier: "ident/general",
  contentHash: "hash",
  size: 100,
);

AppSetting _setting({required bool silentUpdate}) => AppSetting(
  locale: Locale.zh,
  enableDebugLog: false,
  shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
  showCheckoutImpactWarnings: true,
  typeListReturnBehavior: TypeListReturnBehavior.previousPage,
  developerMode: false,
  silentUpdate: silentUpdate,
  remoteContent: const RemoteContentSetting(enabled: true, channel: "testing"),
);

void main() {
  late String tempDir;
  late AppVersionStateStore versionStore;

  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_app_update_gate_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync("efa_app_update_gate_test_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.cachesPath = tempDir;
    versionStore = AppVersionStateStore(settingsPath: tempDir);
    await versionStore.init();
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Widget buildGate({
    required AppSetting setting,
    required RemoteAppRelease release,
    required _FakeAppUpdateController controller,
    AppUpdatePlatformAdapter platformAdapter = const AndroidAppUpdateAdapter(),
    AppUpdateArtifact? artifact,
  }) => ProviderScope(
    overrides: [
      appSettingServiceProvider.overrideWithValue(setting),
      availableAppReleaseProvider.overrideWith((_) async => Some(release)),
      appUpdateControllerProvider(release).overrideWith(() => controller),
      appVersionStateStoreProvider.overrideWithValue(versionStore),
      appVersionProvider.overrideWith((_) async => "1.0.0"),
      appUpdateArtifactProvider.overrideWith((_, _) async => artifact),
      appReleaseNoteProvider.overrideWith((_, _) async => null),
      appUpdatePlatformAdapterProvider.overrideWithValue(platformAdapter),
    ],
    child: testApp(const AppReleaseUpdateGate(child: Scaffold(body: Text("gate child")))),
  );

  testWidgets("default strategy shows the update dialog without downloading", (tester) async {
    final release = _release();
    final controller = _FakeAppUpdateController(
      statusAfterDownload: const AppUpdateStatus.readyToInstall(apkPath: "/tmp/update.apk"),
    );

    await tester.pumpWidget(
      buildGate(setting: _setting(silentUpdate: false), release: release, controller: controller),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppReleaseUpdateDialog), findsOneWidget);
    expect(find.byType(ConfirmDialog), findsNothing);
    expect(controller.downloadCalls, 0);
  });

  testWidgets("silent strategy downloads in background and only asks to install", (tester) async {
    final release = _release();
    final controller = _FakeAppUpdateController(
      statusAfterDownload: const AppUpdateStatus.readyToInstall(apkPath: "/tmp/update.apk"),
    );

    await tester.pumpWidget(
      buildGate(setting: _setting(silentUpdate: true), release: release, controller: controller),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppReleaseUpdateDialog), findsNothing);
    expect(controller.downloadCalls, 1);

    expect(find.byType(ConfirmDialog), findsOneWidget);
    expect(find.text("更新已就绪"), findsOneWidget);
    expect(find.text("新版本 v2.0.0 已下载完成，是否立即安装？"), findsOneWidget);

    await tester.tap(find.text("确认"));
    await tester.pumpAndSettle();

    expect(controller.installCalls, 1);
    // The readyToInstall emission during install() must not re-open the
    // confirmation dialog.
    expect(find.byType(ConfirmDialog), findsNothing);
    // Confirming also acknowledges the version, mirroring the update dialog.
    expect(versionStore.lastSeenAppVersion, "2.0.0");
    expect(versionStore.lastAcknowledgedReleaseId, isNull);
  });

  testWidgets("silent install prompt cancel acknowledges the release", (tester) async {
    final release = _release();
    final controller = _FakeAppUpdateController(
      statusAfterDownload: const AppUpdateStatus.readyToInstall(apkPath: "/tmp/update.apk"),
    );

    await tester.pumpWidget(
      buildGate(setting: _setting(silentUpdate: true), release: release, controller: controller),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ConfirmDialog), findsOneWidget);

    await tester.tap(find.text("取消"));
    await tester.pumpAndSettle();

    expect(controller.installCalls, 0);
    expect(versionStore.lastAcknowledgedReleaseId, "rel-2");
    expect(find.byType(ConfirmDialog), findsNothing);
  });

  testWidgets("silent download failure surfaces no dialog", (tester) async {
    final release = _release();
    final controller = _FakeAppUpdateController(
      statusAfterDownload: const AppUpdateStatus.failed(message: "network down", canRetry: true),
    );

    await tester.pumpWidget(
      buildGate(setting: _setting(silentUpdate: true), release: release, controller: controller),
    );
    await tester.pumpAndSettle();

    expect(controller.downloadCalls, 1);
    expect(find.byType(AppReleaseUpdateDialog), findsNothing);
    expect(find.byType(ConfirmDialog), findsNothing);
    expect(versionStore.lastAcknowledgedReleaseId, isNull);
  });

  testWidgets("platform without self-update shows the manual download dialog", (tester) async {
    final release = _release();
    final controller = _FakeAppUpdateController(
      statusAfterDownload: const AppUpdateStatus.readyToInstall(apkPath: "/tmp/update.apk"),
    );

    await tester.pumpWidget(
      buildGate(
        setting: _setting(silentUpdate: false),
        release: release,
        controller: controller,
        platformAdapter: const LinuxAppUpdateAdapter(),
        artifact: _androidArtifact,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppReleaseUpdateDialog), findsOneWidget);
    expect(find.byType(ManualReleaseDownloadDialog), findsOneWidget);
    expect(controller.downloadCalls, 0);
    // Both Linux artifacts are listed as manual download targets.
    expect(find.text("AppImage"), findsOneWidget);
    expect(find.text("便携压缩包 (.zip)"), findsOneWidget);
    // The Android APK size must not leak into the summary on Linux, even
    // though the release carries a resolvable Android artifact.
    expect(find.text("100B"), findsNothing);
  });

  testWidgets("silent strategy falls back to the manual dialog without self-update", (
    tester,
  ) async {
    final release = _release();
    final controller = _FakeAppUpdateController(
      statusAfterDownload: const AppUpdateStatus.readyToInstall(apkPath: "/tmp/update.apk"),
    );

    await tester.pumpWidget(
      buildGate(
        setting: _setting(silentUpdate: true),
        release: release,
        controller: controller,
        platformAdapter: const LinuxAppUpdateAdapter(),
        artifact: _androidArtifact,
      ),
    );
    await tester.pumpAndSettle();

    // No background download is attempted on platforms without self-update;
    // the manual download dialog is shown instead.
    expect(controller.downloadCalls, 0);
    expect(find.byType(ManualReleaseDownloadDialog), findsOneWidget);
    expect(find.byType(ConfirmDialog), findsNothing);
    // The resolved Android artifact size stays hidden on Linux.
    expect(find.text("100B"), findsNothing);
  });
}
