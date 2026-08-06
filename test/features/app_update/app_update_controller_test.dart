@TestOn("vm")
library;

import "dart:async";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/data/proto/release_index.pb.dart";
import "package:eve_fit_assistant/features/app_update/app_update_service.dart";
import "package:eve_fit_assistant/features/app_update/app_update_status.dart";
import "package:eve_fit_assistant/features/app_update/providers.dart";
import "package:eve_fit_assistant/storage/repo/models/remote_app_release.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:mocktail/mocktail.dart";

class _MockAppUpdateService extends Mock implements AppUpdateService {}

RemoteAppRelease _release({String version = "2.0.0"}) => RemoteAppRelease(
  releaseId: "rel-2",
  version: version,
  snapshotHash: "snapshot",
  index: ReleaseIndex(
    schemaVersion: 1,
    id: "rel-2",
    version: version,
    android: AndroidArtifacts()
      ..general = AndroidArtifactVariant(
        identifier: "release://2.0.0/android/general",
        contentHash: "aa" * 32,
        size: Int64(100),
      ),
  ),
);

void main() {
  late String tempDir;
  late _MockAppUpdateService mockService;
  late ProviderContainer container;

  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_app_update_controller_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_app_update_controller_test_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.cachesPath = tempDir;
    mockService = _MockAppUpdateService();

    container = ProviderContainer(
      overrides: [appUpdateServiceProvider.overrideWithValue(mockService)],
    );
  });

  tearDown(() {
    container.dispose();
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group("AppUpdateController", () {
    test("initial state is idle", () {
      final release = _release();
      final status = container.read(appUpdateControllerProvider(release));

      expect(status, const AppUpdateStatus.idle());
    });

    test("download transitions through downloading to readyToInstall", () async {
      final release = _release();
      final artifact = AppUpdateArtifact(
        variant: "general",
        identifier: "release://2.0.0/android/general",
        contentHash: "aa" * 32,
        size: 100,
      );

      when(
        () => mockService.resolveArtifact(release.index.android),
      ).thenAnswer((_) async => Right(artifact));
      when(
        () => mockService.downloadArtifact(artifact, onProgress: any(named: "onProgress")),
      ).thenAnswer((_) async => const Right("/tmp/update.apk"));

      final states = <AppUpdateStatus>[];
      final sub = container.listen(
        appUpdateControllerProvider(release),
        (_, next) => states.add(next),
        fireImmediately: false,
      );
      addTearDown(sub.close);

      await container.read(appUpdateControllerProvider(release).notifier).download();

      expect(states, hasLength(greaterThanOrEqualTo(2)));
      expect(states.first, isA<AppUpdateStatusDownloading>());
      expect(states.last, const AppUpdateStatus.readyToInstall(apkPath: "/tmp/update.apk"));
    });

    test("download fails when no artifact resolved", () async {
      final release = _release();
      release.index.clearAndroid();

      when(
        () => mockService.resolveArtifact(release.index.android),
      ).thenAnswer((_) async => const Left(AppUpdateNoArtifactError(message: "no artifact")));

      await container.read(appUpdateControllerProvider(release).notifier).download();

      final status = container.read(appUpdateControllerProvider(release));
      expect(status, isA<AppUpdateStatusFailed>());
    });

    test("install transitions to installing then readyToInstall on success", () async {
      final release = _release();
      container.read(appUpdateControllerProvider(release).notifier).state =
          const AppUpdateStatus.readyToInstall(apkPath: "/tmp/update.apk");

      when(() => mockService.canInstall()).thenAnswer((_) async => true);
      when(() => mockService.install("/tmp/update.apk")).thenAnswer((_) async => const Right(unit));

      final states = <AppUpdateStatus>[];
      final sub = container.listen(
        appUpdateControllerProvider(release),
        (_, next) => states.add(next),
        fireImmediately: false,
      );
      addTearDown(sub.close);

      await container.read(appUpdateControllerProvider(release).notifier).install();

      expect(states, hasLength(greaterThanOrEqualTo(2)));
      expect(states.first, const AppUpdateStatus.installing());
      expect(states.last, const AppUpdateStatus.readyToInstall(apkPath: "/tmp/update.apk"));
    });

    test("install fails when permission denied", () async {
      final release = _release();
      container.read(appUpdateControllerProvider(release).notifier).state =
          const AppUpdateStatus.readyToInstall(apkPath: "/tmp/update.apk");

      when(() => mockService.canInstall()).thenAnswer((_) async => false);

      await container.read(appUpdateControllerProvider(release).notifier).install();

      final status = container.read(appUpdateControllerProvider(release));
      expect(status, isA<AppUpdateStatusFailed>());
    });
  });
}
