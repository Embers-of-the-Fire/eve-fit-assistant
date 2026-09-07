import "package:freezed_annotation/freezed_annotation.dart";

part "locale_db_download_state.freezed.dart";

/// Why a per-locale localization database download failed. The dialog maps
/// this reason to a localized message; the raw error text is only written to
/// the logs.
enum LocaleDbDownloadFailureReason {
  /// The fetch failed at the network layer.
  network,

  /// The downloaded payload did not match the expected content hash.
  integrity,

  /// Any other failure.
  unknown,
}

/// State of a per-locale localization database download offered after a
/// locale switch (spec §5.2).
@freezed
sealed class LocaleDbDownloadState with _$LocaleDbDownloadState {
  /// No download has started yet.
  const factory LocaleDbDownloadState.idle() = LocaleDbDownloadIdle;

  /// The database blob is being downloaded (bytes progress).
  const factory LocaleDbDownloadState.downloading({
    required int downloadedBytes,
    required int totalBytes,
  }) = LocaleDbDownloading;

  /// The download failed and can be retried.
  const factory LocaleDbDownloadState.failed({required LocaleDbDownloadFailureReason reason}) =
      LocaleDbDownloadFailed;

  /// The database blob is downloaded and hash-verified; the localization
  /// service has been invalidated so names re-resolve.
  const factory LocaleDbDownloadState.ready() = LocaleDbDownloadReady;
}
