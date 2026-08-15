import "package:eve_fit_assistant/storage/repo/data_update_service.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "batch_data_update_status.freezed.dart";

@freezed
sealed class BatchDataUpdateStatus with _$BatchDataUpdateStatus {
  const factory BatchDataUpdateStatus.unknown() = BatchDataUpdateStatusUnknown;

  const factory BatchDataUpdateStatus.checking() = BatchDataUpdateStatusChecking;

  const factory BatchDataUpdateStatus.upToDate() = BatchDataUpdateStatusUpToDate;

  const factory BatchDataUpdateStatus.available(Map<String, String> newGenerationHashes) =
      BatchDataUpdateStatusAvailable;

  const factory BatchDataUpdateStatus.downloading(BatchUpdateProgress progress) =
      BatchDataUpdateStatusDownloading;

  const factory BatchDataUpdateStatus.applied(BatchUpdateResult result) =
      BatchDataUpdateStatusApplied;

  const factory BatchDataUpdateStatus.failed({required String message, required bool canRetry}) =
      BatchDataUpdateStatusFailed;
}
