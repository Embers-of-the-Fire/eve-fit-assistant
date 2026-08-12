import "package:eve_fit_assistant/features/app_update/models/app_version_state.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_store.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "app_version_state_notifier.g.dart";

/// Singleton store provider. The store is created lazily on first read and
/// initialized during app startup (see init.dart).
@riverpodSingleton
AppVersionStateStore appVersionStateStore(Ref ref) {
  throw UnimplementedError(
    "appVersionStateStoreProvider must be overridden with an initialized store "
    "before use. Call AppVersionStateStore.init() during app startup.",
  );
}

@riverpodSingleton
class AppVersionStateService extends _$AppVersionStateService {
  @override
  AppVersionState build() => ref.watch(appVersionStateStoreProvider).state;

  void acknowledgeVersion(String version) {
    ref.read(appVersionStateStoreProvider).setLastSeenAppVersion(version);
    state = ref.read(appVersionStateStoreProvider).state;
  }

  void acknowledgeRelease(String releaseId) {
    ref.read(appVersionStateStoreProvider).acknowledgeRelease(releaseId);
    state = ref.read(appVersionStateStoreProvider).state;
  }

  void clearReleaseAcknowledgment() {
    ref.read(appVersionStateStoreProvider).clearReleaseAcknowledgment();
    state = ref.read(appVersionStateStoreProvider).state;
  }

  void setPendingInstall(PendingInstall pending) {
    ref.read(appVersionStateStoreProvider).setPendingInstall(pending);
    state = ref.read(appVersionStateStoreProvider).state;
  }

  void clearPendingInstall() {
    ref.read(appVersionStateStoreProvider).clearPendingInstall();
    state = ref.read(appVersionStateStoreProvider).state;
  }
}
