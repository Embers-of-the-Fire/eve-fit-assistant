import "package:freezed_annotation/freezed_annotation.dart";

part "app_version_state.freezed.dart";
part "app_version_state.g.dart";

@freezed
abstract class PendingInstall with _$PendingInstall {
  const factory PendingInstall({
    required String releaseId,
    required String version,
    required String apkPath,
    required String contentHash,
  }) = _PendingInstall;

  factory PendingInstall.fromJson(Map<String, dynamic> json) => _$PendingInstallFromJson(json);
}

@freezed
abstract class AppVersionState with _$AppVersionState {
  const factory AppVersionState({
    @Default(1) int schemaVersion,
    String? lastSeenAppVersion,
    String? lastAcknowledgedReleaseId,
    PendingInstall? pendingInstall,
  }) = _AppVersionState;

  factory AppVersionState.initial() => const AppVersionState();

  factory AppVersionState.fromJson(Map<String, dynamic> json) => _$AppVersionStateFromJson(json);
}
