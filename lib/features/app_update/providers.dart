import "dart:async";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/features/app_update/app_update_service.dart";
import "package:eve_fit_assistant/features/app_update/app_update_status.dart";
import "package:eve_fit_assistant/features/app_update/models/app_version_state.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_notifier.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_store.dart";
import "package:eve_fit_assistant/features/app_update/update_notification.dart";
import "package:eve_fit_assistant/storage/repo/models/remote_app_release.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "providers.g.dart";

@riverpodSingleton
AppUpdateService appUpdateService(Ref ref) =>
    AppUpdateService(remoteCatalogService: ref.watch(remoteCatalogServiceProvider));

/// Tracks the release currently being downloaded/staged in the background,
/// so notification tap handlers can find the session without a UI context.
@riverpodSingleton
class AppUpdateSession extends _$AppUpdateSession {
  @override
  RemoteAppRelease? build() => null;

  void activate(RemoteAppRelease release) => state = release;

  void clear() => state = null;
}

/// Per-release update session. Kept alive so a background download survives
/// dismissal of the update dialog; at most one release downloads at a time
/// (gated by [isBusy] and the update gate).
@riverpodSingleton
class AppUpdateController extends _$AppUpdateController {
  static const Duration _progressNotifyInterval = Duration(milliseconds: 500);

  CancelToken? _cancelToken;
  DateTime _lastProgressNotification = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  AppUpdateStatus build(RemoteAppRelease release) {
    ref.listen(appUpdateServiceProvider, (_, _) {});
    return const AppUpdateStatus.idle();
  }

  AppUpdateService get _service => ref.read(appUpdateServiceProvider);

  UpdateNotificationService get _notifications => ref.read(updateNotificationServiceProvider);

  /// The version-state store, when initialized (it is not in unit tests).
  AppVersionStateStore? get _versionStore {
    try {
      return ref.read(appVersionStateStoreProvider);
    } on Object {
      return null;
    }
  }

  bool get isBusy => switch (state) {
    AppUpdateStatusDownloading() ||
    AppUpdateStatusVerifying() ||
    AppUpdateStatusInstalling() => true,
    _ => false,
  };

  Future<void> download() async {
    if (isBusy) return;

    final artifacts = release.index.android;
    if (!artifacts.hasGeneral()) {
      state = const AppUpdateStatus.failed(
        message: "No Android APK available for this release.",
        canRetry: false,
      );
      return;
    }

    final artifactResult = await _service.resolveArtifact(artifacts);
    if (artifactResult.isLeft()) {
      final error = artifactResult.getLeft().toNullable()!;
      state = AppUpdateStatus.failed(message: error.toString(), canRetry: false);
      return;
    }
    final artifact = artifactResult.getRight().toNullable()!;

    // A new download supersedes any previously staged install.
    _versionStore?.clearPendingInstall();
    ref.read(appUpdateSessionProvider.notifier).activate(release);

    final notifications = _notifications;
    unawaited(notifications.ensurePermission());
    notifications.onCancelRequested = cancel;

    state = AppUpdateStatus.downloading(receivedBytes: 0, totalBytes: artifact.size);
    unawaited(notifications.showDownloadProgress(receivedBytes: 0, totalBytes: artifact.size));

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    final downloadResult = await _service.downloadArtifact(
      artifact,
      cancelToken: cancelToken,
      onProgress: (received, total) {
        state = AppUpdateStatus.downloading(receivedBytes: received, totalBytes: total);
        _notifyProgressThrottled(received, total);
      },
    );
    _cancelToken = null;

    if (downloadResult.isLeft()) {
      final error = downloadResult.getLeft().toNullable()!;
      if (error is AppUpdateCancelledError) {
        state = const AppUpdateStatus.idle();
        unawaited(notifications.dismiss());
        return;
      }
      state = AppUpdateStatus.failed(message: error.toString(), canRetry: true);
      unawaited(notifications.showFailed());
      return;
    }

    final apkPath = downloadResult.getRight().toNullable()!;
    state = AppUpdateStatus.readyToInstall(apkPath: apkPath);
    _versionStore?.setPendingInstall(
      PendingInstall(
        releaseId: release.releaseId,
        version: release.version,
        apkPath: apkPath,
        contentHash: artifact.contentHash,
      ),
    );
    unawaited(notifications.showReadyToInstall(version: release.version));
  }

  void _notifyProgressThrottled(int received, int total) {
    final now = DateTime.now();
    if (received < total && now.difference(_lastProgressNotification) < _progressNotifyInterval) {
      return;
    }
    _lastProgressNotification = now;
    unawaited(_notifications.showDownloadProgress(receivedBytes: received, totalBytes: total));
  }

  /// Cancels an in-flight download. The partial file is kept for later
  /// resume and the session returns to [AppUpdateStatusIdle].
  void cancel() => _cancelToken?.cancel();

  /// Restores a previously staged install (e.g. after an app restart) so the
  /// gate can prompt for installation without re-downloading.
  void markReadyToInstall(String apkPath) {
    if (isBusy) return;
    state = AppUpdateStatus.readyToInstall(apkPath: apkPath);
  }

  Future<void> install() async {
    final current = state;
    if (current is! AppUpdateStatusReadyToInstall) return;

    final apkPath = current.apkPath;
    final canInstall = await _service.canInstall();
    if (!canInstall) {
      state = const AppUpdateStatus.failed(
        message: "Install permission is required to update the app.",
        canRetry: true,
        permissionRequired: true,
      );
      return;
    }

    state = const AppUpdateStatus.installing();
    final result = await _service.install(apkPath);
    if (result.isLeft()) {
      final error = result.getLeft().toNullable()!;
      state = AppUpdateStatus.failed(message: error.toString(), canRetry: true);
      return;
    }

    state = AppUpdateStatus.readyToInstall(apkPath: apkPath);
  }

  Future<void> openPermissionSettings() async {
    final result = await _service.openInstallPermissionSettings();
    if (result.isLeft()) {
      final error = result.getLeft().toNullable()!;
      state = AppUpdateStatus.failed(message: error.toString(), canRetry: true);
    }
  }

  void retry() {
    final current = state;
    if (current is AppUpdateStatusFailed && !current.canRetry) return;
    unawaited(download());
  }

  void reset() => state = const AppUpdateStatus.idle();
}
