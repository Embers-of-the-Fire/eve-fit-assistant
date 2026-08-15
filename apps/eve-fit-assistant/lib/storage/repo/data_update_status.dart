import "package:freezed_annotation/freezed_annotation.dart";

part "data_update_status.freezed.dart";

@freezed
sealed class DataUpdateStatus with _$DataUpdateStatus {
  const factory DataUpdateStatus.unknown() = DataUpdateStatusUnknown;

  const factory DataUpdateStatus.checking() = DataUpdateStatusChecking;

  const factory DataUpdateStatus.upToDate({required String currentGenerationHash}) =
      DataUpdateStatusUpToDate;

  const factory DataUpdateStatus.available({
    required String currentGenerationHash,
    required String newGenerationHash,
  }) = DataUpdateStatusAvailable;

  const factory DataUpdateStatus.downloading({
    required int downloadedCount,
    required int totalCount,
  }) = DataUpdateStatusDownloading;

  const factory DataUpdateStatus.applied({required String newSnapshotHash}) =
      DataUpdateStatusApplied;

  const factory DataUpdateStatus.failed({required String message, required bool canRetry}) =
      DataUpdateStatusFailed;
}
