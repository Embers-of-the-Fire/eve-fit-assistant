import "dart:async";

import "package:eve_fit_assistant/features/app_update/app_update_service.dart";
import "package:eve_fit_assistant/features/app_update/app_update_status.dart";
import "package:eve_fit_assistant/storage/repo/models/remote_app_release.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "providers.g.dart";

@riverpodSingleton
AppUpdateService appUpdateService(Ref ref) =>
    AppUpdateService(remoteCatalogService: ref.watch(remoteCatalogServiceProvider));

@riverpod
class AppUpdateController extends _$AppUpdateController {
  @override
  AppUpdateStatus build(RemoteAppRelease release) {
    ref.listen(appUpdateServiceProvider, (_, _) {});
    return const AppUpdateStatus.idle();
  }

  AppUpdateService get _service => ref.read(appUpdateServiceProvider);

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

    state = AppUpdateStatus.downloading(receivedBytes: 0, totalBytes: artifact.size);

    final downloadResult = await _service.downloadArtifact(
      artifact,
      onProgress: (received, total) {
        state = AppUpdateStatus.downloading(receivedBytes: received, totalBytes: total);
      },
    );

    if (downloadResult.isLeft()) {
      final error = downloadResult.getLeft().toNullable()!;
      state = AppUpdateStatus.failed(message: error.toString(), canRetry: true);
      return;
    }

    final apkPath = downloadResult.getRight().toNullable()!;
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
