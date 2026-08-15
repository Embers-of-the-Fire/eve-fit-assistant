@TestOn("vm")
library;

import "dart:async";
import "dart:io";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:efa_proto/release_index.pb.dart";
import "package:eve_fit_assistant/features/app_update/app_update_service.dart";
import "package:eve_fit_assistant/features/app_update/app_update_status.dart";
import "package:eve_fit_assistant/features/app_update/providers.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_notifier.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_store.dart";
import "package:eve_fit_assistant/features/app_update/update_notification.dart";
import "package:eve_fit_assistant/storage/fs/file_doc_store.dart";
import "package:eve_fit_assistant/storage/repo/models/remote_app_release.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:mocktail/mocktail.dart";

class _MockAppUpdateService extends Mock implements AppUpdateService {}

class _FakeUpdateNotificationService implements UpdateNotificationService {
  @override
  void Function()? onInstallRequested;

  @override
  void Function()? onCancelRequested;

  final progressCalls = <(int, int)>[];
  var readyCalls = 0;
  var failedCalls = 0;
  var dismissCalls = 0;
  var permissionCalls = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> ensurePermission() async {
    permissionCalls += 1;
    return true;
  }

  @override
  Future<void> showDownloadProgress({required int receivedBytes, required int totalBytes}) async {
    progressCalls.add((receivedBytes, totalBytes));
  }

  @override
  Future<void> showReadyToInstall({required String version}) async {
    readyCalls += 1;
  }

  @override
  Future<void> showFailed() async {
    failedCalls += 1;
  }

  @override
  Future<void> dismiss() async {
    dismissCalls += 1;
  }
}

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
    registerFallbackValue(CancelToken());
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
        () => mockService.downloadArtifact(
          artifact,
          onProgress: any(named: "onProgress"),
          cancelToken: any(named: "cancelToken"),
        ),
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

  group("background session", () {
    late AppVersionStateStore versionStore;
    late _FakeUpdateNotificationService notifications;
    late ProviderContainer sessionContainer;

    setUp(() async {
      versionStore = AppVersionStateStore(store: FileDocStore(tempDir));
      await versionStore.init();
      notifications = _FakeUpdateNotificationService();
      sessionContainer = ProviderContainer(
        overrides: [
          appUpdateServiceProvider.overrideWithValue(mockService),
          updateNotificationServiceProvider.overrideWithValue(notifications),
          appVersionStateStoreProvider.overrideWithValue(versionStore),
        ],
      );
    });

    tearDown(() {
      sessionContainer.dispose();
    });

    AppUpdateArtifact stubSuccessfulDownload(RemoteAppRelease release, String apkPath) {
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
        () => mockService.downloadArtifact(
          artifact,
          onProgress: any(named: "onProgress"),
          cancelToken: any(named: "cancelToken"),
        ),
      ).thenAnswer((invocation) async {
        final onProgress = invocation.namedArguments[#onProgress] as void Function(int, int)?;
        onProgress?.call(artifact.size, artifact.size);
        return Right(apkPath);
      });
      return artifact;
    }

    test("download stages pendingInstall, activates session, and notifies", () async {
      final release = _release();
      stubSuccessfulDownload(release, "/tmp/update.apk");

      await sessionContainer.read(appUpdateControllerProvider(release).notifier).download();

      final pending = versionStore.pendingInstall;
      expect(pending, isNotNull);
      expect(pending!.releaseId, release.releaseId);
      expect(pending.version, release.version);
      expect(pending.apkPath, "/tmp/update.apk");
      expect(pending.contentHash, "aa" * 32);

      expect(sessionContainer.read(appUpdateSessionProvider), release);
      expect(notifications.permissionCalls, greaterThanOrEqualTo(1));
      expect(notifications.progressCalls, isNotEmpty);
      expect(notifications.readyCalls, 1);
      expect(notifications.failedCalls, 0);
      expect(notifications.onCancelRequested, isNotNull);
    });

    test("cancelled download returns to idle, dismisses notification, stages nothing", () async {
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
        () => mockService.downloadArtifact(
          artifact,
          onProgress: any(named: "onProgress"),
          cancelToken: any(named: "cancelToken"),
        ),
      ).thenAnswer((_) async => const Left(AppUpdateCancelledError()));

      await sessionContainer.read(appUpdateControllerProvider(release).notifier).download();

      expect(
        sessionContainer.read(appUpdateControllerProvider(release)),
        const AppUpdateStatus.idle(),
      );
      expect(notifications.dismissCalls, 1);
      expect(notifications.readyCalls, 0);
      expect(versionStore.pendingInstall, isNull);
    });

    test("failed download surfaces a failure notification and stages nothing", () async {
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
        () => mockService.downloadArtifact(
          artifact,
          onProgress: any(named: "onProgress"),
          cancelToken: any(named: "cancelToken"),
        ),
      ).thenAnswer((_) async => const Left(AppUpdateDownloadError(message: "network down")));

      await sessionContainer.read(appUpdateControllerProvider(release).notifier).download();

      expect(
        sessionContainer.read(appUpdateControllerProvider(release)),
        isA<AppUpdateStatusFailed>(),
      );
      expect(notifications.failedCalls, 1);
      expect(notifications.readyCalls, 0);
      expect(versionStore.pendingInstall, isNull);
    });

    test("markReadyToInstall restores a staged install", () {
      final release = _release();
      sessionContainer
          .read(appUpdateControllerProvider(release).notifier)
          .markReadyToInstall("/tmp/staged.apk");

      expect(
        sessionContainer.read(appUpdateControllerProvider(release)),
        const AppUpdateStatus.readyToInstall(apkPath: "/tmp/staged.apk"),
      );
    });
  });
}
