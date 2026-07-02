import "dart:async";
import "dart:io";

import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/data/proto/generation_pointer.pb.dart";
import "package:eve_fit_assistant/features/announcements/state/announcement_state_store.dart";
import "package:eve_fit_assistant/storage/repo/channel_service.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/release_sync.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:mocktail/mocktail.dart";

class MockChannelService extends Mock implements ChannelService {}

class MockReleaseSyncService extends Mock implements ReleaseSyncService {}

void main() {
  late String tempDir;
  late MockChannelService mockChannelService;
  late MockReleaseSyncService mockReleaseSyncService;

  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_app_release_provider_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_app_release_provider_test_").path;
    PathProvider.documentsPath = tempDir;
    AnnouncementStateStore.init();

    mockChannelService = MockChannelService();
    mockReleaseSyncService = MockReleaseSyncService();
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  ProviderContainer _container({required bool remoteEnabled, String channel = "testing"}) =>
      ProviderContainer(
        overrides: [
          appSettingServiceProvider.overrideWithValue(
            AppSetting(
              locale: Locale.en,
              enableDebugLog: false,
              shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
              showCheckoutImpactWarnings: true,
              typeListReturnBehavior: TypeListReturnBehavior.previousPage,
              developerMode: false,
              remoteContent: RemoteContentSetting(enabled: remoteEnabled, channel: channel),
            ),
          ),
          channelServiceProvider.overrideWith((_) => mockChannelService),
          releaseSyncServiceProvider.overrideWith((_) => mockReleaseSyncService),
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
      () => mockReleaseSyncService.checkFromSnapshotHash(snapshotHash: "release_snapshot"),
    ).thenAnswer(
      (_) async => const Right(Some(RemoteAppRelease(releaseId: "rel-2", version: "2.0.0"))),
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

    AnnouncementStateStore.acknowledgeRelease("rel-2");

    final pointer = GenerationPointer(schemaVersion: 1, snapshotHash: "release_snapshot");
    when(() => mockChannelService.readReleasePointer("testing")).thenReturn(Some(pointer));
    when(
      () => mockReleaseSyncService.checkFromSnapshotHash(snapshotHash: "release_snapshot"),
    ).thenAnswer(
      (_) async => const Right(Some(RemoteAppRelease(releaseId: "rel-2", version: "2.0.0"))),
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
      () => mockReleaseSyncService.checkFromSnapshotHash(snapshotHash: "release_snapshot"),
    ).thenAnswer(
      (_) async => const Right(Some(RemoteAppRelease(releaseId: "rel-2", version: "2.0.0"))),
    );

    await container.read(availableAppReleaseProvider.future);
    container.read(availableAppReleaseProvider.notifier).acknowledge("rel-2");
    final result = await container.read(availableAppReleaseProvider.future);

    expect(result, const None());
    expect(AnnouncementStateStore.lastAcknowledgedReleaseId, "rel-2");
  });

  test("surfaces sync errors as AsyncError", () async {
    final container = _container(remoteEnabled: true);
    addTearDown(container.dispose);

    final pointer = GenerationPointer(schemaVersion: 1, snapshotHash: "release_snapshot");
    when(() => mockChannelService.readReleasePointer("testing")).thenReturn(Some(pointer));
    when(
      () => mockReleaseSyncService.checkFromSnapshotHash(snapshotHash: "release_snapshot"),
    ).thenAnswer((_) async => Left(ReleaseSyncNetworkError(message: "network down")));

    final completer = Completer<Object>();
    final sub = container.listen(availableAppReleaseProvider, (_, next) {
      if (next.hasError && !completer.isCompleted) {
        completer.complete(next.error!);
      }
    }, fireImmediately: true);
    addTearDown(sub.close);

    final error = await completer.future;
    expect(error, isA<ReleaseSyncNetworkError>());
  });
}
