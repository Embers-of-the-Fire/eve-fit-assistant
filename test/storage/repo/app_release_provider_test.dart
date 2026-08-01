import "dart:async";
import "dart:io";

import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/data/proto/generation_pointer.pb.dart";
import "package:eve_fit_assistant/data/proto/release_index.pb.dart";
import "package:eve_fit_assistant/features/app_update/platform/update_platform.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_notifier.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_store.dart";
import "package:eve_fit_assistant/storage/repo/channel_service.dart";
import "package:eve_fit_assistant/storage/repo/models/remote_app_release.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/release_sync.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:mocktail/mocktail.dart";

class MockChannelService extends Mock implements ChannelService {}

class MockReleaseSyncService extends Mock implements ReleaseSyncService {}

AndroidArtifacts _androidArtifacts() => AndroidArtifacts(
  general: AndroidArtifactVariant(identifier: "ident/general", contentHash: "hash", size: Int64(1)),
);

LinuxArtifacts _linuxArtifacts() => LinuxArtifacts(
  appimage: LinuxArtifactVariant(identifier: "ident/appimage", contentHash: "hash", size: Int64(1)),
);

RemoteAppRelease _release({
  required String releaseId,
  required String version,
  bool withAndroid = true,
  bool withLinux = true,
}) => RemoteAppRelease(
  releaseId: releaseId,
  version: version,
  snapshotHash: "release_snapshot",
  index: ReleaseIndex(
    schemaVersion: 1,
    id: releaseId,
    version: version,
    android: withAndroid ? _androidArtifacts() : null,
    linux: withLinux ? _linuxArtifacts() : null,
  ),
);

void main() {
  late String tempDir;
  late MockChannelService mockChannelService;
  late MockReleaseSyncService mockReleaseSyncService;
  late AppVersionStateStore versionStore;

  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_app_release_provider_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync("efa_app_release_provider_test_").path;
    PathProvider.documentsPath = tempDir;
    versionStore = AppVersionStateStore(settingsPath: tempDir);
    await versionStore.init();

    mockChannelService = MockChannelService();
    mockReleaseSyncService = MockReleaseSyncService();
  });

  tearDown(() async {
    await versionStore.ensureSynced;
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  ProviderContainer _container({
    required bool remoteEnabled,
    String channel = "testing",
    bool ignoreBugfixUpdates = false,
    AppUpdatePlatformAdapter? platformAdapter,
  }) => ProviderContainer(
    overrides: [
      appSettingServiceProvider.overrideWithValue(
        AppSetting(
          locale: Locale.en,
          enableDebugLog: false,
          shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
          showCheckoutImpactWarnings: true,
          typeListReturnBehavior: TypeListReturnBehavior.previousPage,
          developerMode: false,
          ignoreBugfixUpdates: ignoreBugfixUpdates,
          remoteContent: RemoteContentSetting(enabled: remoteEnabled, channel: channel),
        ),
      ),
      appVersionStateStoreProvider.overrideWithValue(versionStore),
      channelServiceProvider.overrideWith((_) => mockChannelService),
      releaseSyncServiceProvider.overrideWith((_) => mockReleaseSyncService),
      if (platformAdapter != null)
        appUpdatePlatformAdapterProvider.overrideWithValue(platformAdapter),
    ],
  );

  test("returns None when remote content is disabled", () async {
    final container = _container(remoteEnabled: false);
    addTearDown(container.dispose);

    final result = await container.read(availableAppReleaseProvider.future);

    expect(result, const None());
  });

  test("returns None when configured channel is empty", () async {
    final container = _container(remoteEnabled: true, channel: "");
    addTearDown(container.dispose);

    final result = await container.read(availableAppReleaseProvider.future);

    expect(result, const None());
  });

  test("returns None when no release pointer is available locally", () async {
    final container = _container(remoteEnabled: true);
    addTearDown(container.dispose);

    when(() => mockChannelService.readReleasePointer("testing")).thenReturn(const None());

    final result = await container.read(availableAppReleaseProvider.future);

    expect(result, const None());
  });

  test("returns available release when remote version is newer", () async {
    final container = _container(remoteEnabled: true);
    addTearDown(container.dispose);

    final pointer = GenerationPointer(schemaVersion: 1, snapshotHash: "release_snapshot");
    when(() => mockChannelService.readReleasePointer("testing")).thenReturn(Some(pointer));
    when(
      () => mockReleaseSyncService.checkStatusFromSnapshotHash(
        snapshotHash: "release_snapshot",
        ignoreBugfix: any(named: "ignoreBugfix"),
      ),
    ).thenAnswer(
      (_) async => Right(
        ReleaseCheckUpdateAvailable(
          release: _release(releaseId: "rel-2", version: "2.0.0"),
        ),
      ),
    );

    final result = await container.read(availableAppReleaseProvider.future);

    final release = result.toNullable();
    expect(release, isNotNull);
    expect(release!.releaseId, "rel-2");
    expect(release.version, "2.0.0");
  });

  test("hides acknowledged release", () async {
    final container = _container(remoteEnabled: true);
    addTearDown(container.dispose);

    versionStore.acknowledgeRelease("rel-2");

    final pointer = GenerationPointer(schemaVersion: 1, snapshotHash: "release_snapshot");
    when(() => mockChannelService.readReleasePointer("testing")).thenReturn(Some(pointer));
    when(
      () => mockReleaseSyncService.checkStatusFromSnapshotHash(
        snapshotHash: "release_snapshot",
        ignoreBugfix: any(named: "ignoreBugfix"),
      ),
    ).thenAnswer(
      (_) async => Right(
        ReleaseCheckUpdateAvailable(
          release: _release(releaseId: "rel-2", version: "2.0.0"),
        ),
      ),
    );

    final result = await container.read(availableAppReleaseProvider.future);

    expect(result, const None());
  });

  test("acknowledge hides the release", () async {
    final container = _container(remoteEnabled: true);
    addTearDown(container.dispose);

    final pointer = GenerationPointer(schemaVersion: 1, snapshotHash: "release_snapshot");
    when(() => mockChannelService.readReleasePointer("testing")).thenReturn(Some(pointer));
    when(
      () => mockReleaseSyncService.checkStatusFromSnapshotHash(
        snapshotHash: "release_snapshot",
        ignoreBugfix: any(named: "ignoreBugfix"),
      ),
    ).thenAnswer(
      (_) async => Right(
        ReleaseCheckUpdateAvailable(
          release: _release(releaseId: "rel-2", version: "2.0.0"),
        ),
      ),
    );

    await container.read(availableAppReleaseProvider.future);
    container.read(appVersionStateServiceProvider.notifier).acknowledgeRelease("rel-2");
    container.invalidate(availableAppReleaseProvider);
    final result = await container.read(availableAppReleaseProvider.future);

    expect(result, const None());
    expect(versionStore.lastAcknowledgedReleaseId, "rel-2");
  });

  test("re-detects release after pointer is cached and base provider is invalidated", () async {
    final container = _container(remoteEnabled: true);
    addTearDown(container.dispose);

    // First-run state: the release pointer is not cached locally yet.
    when(() => mockChannelService.readReleasePointer("testing")).thenReturn(const None());

    // Keep the provider alive for the whole scenario, mirroring the
    // AppReleaseUpdateGate listener in production.
    final sub = container.listen(availableAppReleaseProvider, (_, _) {});
    addTearDown(sub.close);

    final initial = await container.read(availableAppReleaseProvider.future);
    expect(initial, const None());

    // The startup background sync persists the pointer, then invalidates the
    // base provider so the fresh pointer is re-read.
    final pointer = GenerationPointer(schemaVersion: 1, snapshotHash: "release_snapshot");
    when(() => mockChannelService.readReleasePointer("testing")).thenReturn(Some(pointer));
    when(
      () => mockReleaseSyncService.checkStatusFromSnapshotHash(
        snapshotHash: "release_snapshot",
        ignoreBugfix: any(named: "ignoreBugfix"),
      ),
    ).thenAnswer(
      (_) async => Right(
        ReleaseCheckUpdateAvailable(
          release: _release(releaseId: "rel-2", version: "2.0.0"),
        ),
      ),
    );

    container.invalidate(appReleaseCheckStatusProvider);
    final result = await container.read(availableAppReleaseProvider.future);

    final release = result.toNullable();
    expect(release, isNotNull);
    expect(release!.releaseId, "rel-2");
  });

  test("re-detection requires invalidating the base appReleaseCheckStatusProvider", () async {
    final container = _container(remoteEnabled: true);
    addTearDown(container.dispose);

    when(() => mockChannelService.readReleasePointer("testing")).thenReturn(const None());

    final sub = container.listen(availableAppReleaseProvider, (_, _) {});
    addTearDown(sub.close);

    final initial = await container.read(availableAppReleaseProvider.future);
    expect(initial, const None());

    final pointer = GenerationPointer(schemaVersion: 1, snapshotHash: "release_snapshot");
    when(() => mockChannelService.readReleasePointer("testing")).thenReturn(Some(pointer));
    when(
      () => mockReleaseSyncService.checkStatusFromSnapshotHash(
        snapshotHash: "release_snapshot",
        ignoreBugfix: any(named: "ignoreBugfix"),
      ),
    ).thenAnswer(
      (_) async => Right(
        ReleaseCheckUpdateAvailable(
          release: _release(releaseId: "rel-2", version: "2.0.0"),
        ),
      ),
    );

    // Invalidating only the derived provider reuses the stale base value; the
    // startup sync must invalidate appReleaseCheckStatusProvider instead (see
    // RepoStateNotifier._startBackgroundSync).
    container.invalidate(availableAppReleaseProvider);
    final stale = await container.read(availableAppReleaseProvider.future);
    expect(stale, const None());

    container.invalidate(appReleaseCheckStatusProvider);
    final result = await container.read(availableAppReleaseProvider.future);
    expect(result.toNullable()?.releaseId, "rel-2");
  });

  test("status provider reports unavailable when no release pointer is cached", () async {
    final container = _container(remoteEnabled: true);
    addTearDown(container.dispose);

    when(() => mockChannelService.readReleasePointer("testing")).thenReturn(const None());

    final status = await container.read(appReleaseCheckStatusProvider.future);

    expect(status, isA<ReleaseCheckUnavailable>());
  });

  test("status provider reports upToDate when the pointer has no snapshot hash", () async {
    final container = _container(remoteEnabled: true);
    addTearDown(container.dispose);

    // Channels without any published app release have a generation pointer
    // with an empty snapshot hash.
    final pointer = GenerationPointer(schemaVersion: 1, snapshotHash: "");
    when(() => mockChannelService.readReleasePointer("testing")).thenReturn(Some(pointer));

    final status = await container.read(appReleaseCheckStatusProvider.future);

    expect(status, isA<ReleaseCheckUpToDate>());
    expect(await container.read(remoteAppReleaseProvider.future), const None());
  });

  test("status provider reports upToDate when versions match", () async {
    final container = _container(remoteEnabled: true);
    addTearDown(container.dispose);

    final pointer = GenerationPointer(schemaVersion: 1, snapshotHash: "release_snapshot");
    when(() => mockChannelService.readReleasePointer("testing")).thenReturn(Some(pointer));
    when(
      () => mockReleaseSyncService.checkStatusFromSnapshotHash(
        snapshotHash: "release_snapshot",
        ignoreBugfix: any(named: "ignoreBugfix"),
      ),
    ).thenAnswer((_) async => const Right(ReleaseCheckUpToDate()));

    final status = await container.read(appReleaseCheckStatusProvider.future);

    expect(status, isA<ReleaseCheckUpToDate>());
    expect(await container.read(remoteAppReleaseProvider.future), const None());
  });

  test("status provider reports aheadOfRemote without surfacing a release", () async {
    final container = _container(remoteEnabled: true);
    addTearDown(container.dispose);

    final pointer = GenerationPointer(schemaVersion: 1, snapshotHash: "release_snapshot");
    when(() => mockChannelService.readReleasePointer("testing")).thenReturn(Some(pointer));
    when(
      () => mockReleaseSyncService.checkStatusFromSnapshotHash(
        snapshotHash: "release_snapshot",
        ignoreBugfix: any(named: "ignoreBugfix"),
      ),
    ).thenAnswer((_) async => const Right(ReleaseCheckAheadOfRemote(remoteVersion: "0.9.0")));

    final status = await container.read(appReleaseCheckStatusProvider.future);

    expect(status, isA<ReleaseCheckAheadOfRemote>());
    expect((status as ReleaseCheckAheadOfRemote).remoteVersion, "0.9.0");
    expect(await container.read(remoteAppReleaseProvider.future), const None());
  });

  test("surfaces sync errors as AsyncError", () async {
    final container = _container(remoteEnabled: true);

    final pointer = GenerationPointer(schemaVersion: 1, snapshotHash: "release_snapshot");
    when(() => mockChannelService.readReleasePointer("testing")).thenReturn(Some(pointer));
    when(
      () => mockReleaseSyncService.checkStatusFromSnapshotHash(
        snapshotHash: "release_snapshot",
        ignoreBugfix: any(named: "ignoreBugfix"),
      ),
    ).thenAnswer((_) async => Left(ReleaseSyncNetworkError(message: "network down")));

    final errorObserved = Completer<void>();
    final sub = container.listen(appReleaseCheckStatusProvider, (previous, next) {
      if (next.hasError && next.error is ReleaseSyncNetworkError && !errorObserved.isCompleted) {
        errorObserved.complete();
      }
    });
    await errorObserved.future;
    sub.close();
    container.dispose();
  });

  test("forwards the ignoreBugfixUpdates setting to the sync service", () async {
    final container = _container(remoteEnabled: true, ignoreBugfixUpdates: true);
    addTearDown(container.dispose);

    final pointer = GenerationPointer(schemaVersion: 1, snapshotHash: "release_snapshot");
    when(() => mockChannelService.readReleasePointer("testing")).thenReturn(Some(pointer));
    when(
      () => mockReleaseSyncService.checkStatusFromSnapshotHash(
        snapshotHash: "release_snapshot",
        ignoreBugfix: true,
      ),
    ).thenAnswer((_) async => const Right(ReleaseCheckUpToDate()));

    final status = await container.read(appReleaseCheckStatusProvider.future);

    expect(status, isA<ReleaseCheckUpToDate>());
    verify(
      () => mockReleaseSyncService.checkStatusFromSnapshotHash(
        snapshotHash: "release_snapshot",
        ignoreBugfix: true,
      ),
    ).called(1);
  });

  test("defaults to forwarding ignoreBugfix as false", () async {
    final container = _container(remoteEnabled: true);
    addTearDown(container.dispose);

    final pointer = GenerationPointer(schemaVersion: 1, snapshotHash: "release_snapshot");
    when(() => mockChannelService.readReleasePointer("testing")).thenReturn(Some(pointer));
    when(
      () => mockReleaseSyncService.checkStatusFromSnapshotHash(
        snapshotHash: "release_snapshot",
        ignoreBugfix: false,
      ),
    ).thenAnswer((_) async => const Right(ReleaseCheckUpToDate()));

    final status = await container.read(appReleaseCheckStatusProvider.future);

    expect(status, isA<ReleaseCheckUpToDate>());
    verify(
      () => mockReleaseSyncService.checkStatusFromSnapshotHash(
        snapshotHash: "release_snapshot",
        ignoreBugfix: false,
      ),
    ).called(1);
  });

  void stubUpdateAvailable(RemoteAppRelease release) {
    final pointer = GenerationPointer(schemaVersion: 1, snapshotHash: "release_snapshot");
    when(() => mockChannelService.readReleasePointer("testing")).thenReturn(Some(pointer));
    when(
      () => mockReleaseSyncService.checkStatusFromSnapshotHash(
        snapshotHash: "release_snapshot",
        ignoreBugfix: any(named: "ignoreBugfix"),
      ),
    ).thenAnswer((_) async => Right(ReleaseCheckUpdateAvailable(release: release)));
  }

  test("filters out a release without artifacts for the current platform", () async {
    final container = _container(
      remoteEnabled: true,
      platformAdapter: const LinuxAppUpdateAdapter(),
    );
    addTearDown(container.dispose);

    stubUpdateAvailable(_release(releaseId: "rel-2", version: "2.0.0", withLinux: false));

    final status = await container.read(appReleaseCheckStatusProvider.future);

    expect(status, isA<ReleaseCheckUpToDate>());
    expect(await container.read(remoteAppReleaseProvider.future), const None());
    expect(await container.read(availableAppReleaseProvider.future), const None());
  });

  test("surfaces a release with artifacts for the current platform", () async {
    final container = _container(
      remoteEnabled: true,
      platformAdapter: const LinuxAppUpdateAdapter(),
    );
    addTearDown(container.dispose);

    stubUpdateAvailable(_release(releaseId: "rel-2", version: "2.0.0", withAndroid: false));

    final status = await container.read(appReleaseCheckStatusProvider.future);

    expect(status, isA<ReleaseCheckUpdateAvailable>());
    final release = await container.read(availableAppReleaseProvider.future);
    expect(release.toNullable()?.releaseId, "rel-2");
  });

  test("filters out every release on an unsupported platform", () async {
    final container = _container(
      remoteEnabled: true,
      platformAdapter: const UnsupportedAppUpdateAdapter(),
    );
    addTearDown(container.dispose);

    stubUpdateAvailable(_release(releaseId: "rel-2", version: "2.0.0"));

    final status = await container.read(appReleaseCheckStatusProvider.future);

    expect(status, isA<ReleaseCheckUpToDate>());
    expect(await container.read(availableAppReleaseProvider.future), const None());
  });
}
