import "package:freezed_annotation/freezed_annotation.dart";

part "app_update_status.freezed.dart";

@freezed
sealed class AppUpdateStatus with _$AppUpdateStatus {
  const factory AppUpdateStatus.idle() = AppUpdateStatusIdle;

  const factory AppUpdateStatus.downloading({required int receivedBytes, required int totalBytes}) =
      AppUpdateStatusDownloading;

  const factory AppUpdateStatus.verifying() = AppUpdateStatusVerifying;

  const factory AppUpdateStatus.readyToInstall({required String apkPath}) =
      AppUpdateStatusReadyToInstall;

  const factory AppUpdateStatus.installing() = AppUpdateStatusInstalling;

  const factory AppUpdateStatus.failed({
    required String message,
    required bool canRetry,
    @Default(false) bool permissionRequired,
  }) = AppUpdateStatusFailed;
}
