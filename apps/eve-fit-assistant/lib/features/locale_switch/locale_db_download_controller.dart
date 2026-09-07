import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/locale_switch/locale_db_download_state.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/localization_db.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "locale_db_download_controller.g.dart";

/// Downloads a locale's per-locale localization database on demand, reporting
/// byte progress through [LocaleDbDownloadState].
///
/// Mirrors the AI gate's agent-database download: the payload is
/// hash-verified before it is persisted into the content-addressed store, and
/// the availability/service providers are invalidated afterwards so names
/// re-resolve through the §4.3 lookup chain.
@riverpod
class LocaleDbDownloadController extends _$LocaleDbDownloadController {
  @override
  LocaleDbDownloadState build(String locale) => const LocaleDbDownloadState.idle();

  /// Downloads the per-locale database for [locale] from the active
  /// checkout's remote catalog.
  Future<void> download() async {
    state = const LocaleDbDownloadState.downloading(downloadedBytes: 0, totalBytes: 0);
    try {
      final proxy = await ref.read(resourceBlobProxyProvider.future);
      final resourceId = localeLocalizationDbResourceId(locale);
      final entry = proxy?.entry(resourceId);
      if (entry == null) {
        warning("Locale DB download: $resourceId absent from the checkout index");
        state = const LocaleDbDownloadState.failed(reason: LocaleDbDownloadFailureReason.unknown);
        return;
      }

      final identHash = RepoHash.hashIdent(resourceId);
      final expectedBytes = entry.size.toInt();
      final result = await ref
          .read(remoteCatalogServiceProvider)
          .fetchBlob(
            identHash,
            entry.contentHash,
            onReceiveProgress: (received, total) {
              if (!ref.mounted) return;
              state = LocaleDbDownloadState.downloading(
                downloadedBytes: received,
                totalBytes: total > 0 ? total : expectedBytes,
              );
            },
          );
      if (result.isLeft()) {
        final err = result.getLeft().toNullable()!;
        warning("Locale DB download failed for $locale: $err");
        state = LocaleDbDownloadState.failed(
          reason: err is CatalogNetworkError
              ? LocaleDbDownloadFailureReason.network
              : LocaleDbDownloadFailureReason.unknown,
        );
        return;
      }

      final bytes = result.getRight().toNullable()!;
      if (RepoHash.hashContent(bytes) != entry.contentHash) {
        warning("Locale DB download content hash mismatch for $locale");
        state = const LocaleDbDownloadState.failed(reason: LocaleDbDownloadFailureReason.integrity);
        return;
      }
      await ref
          .read(assetStoreProvider)
          .writeBlobUncheckedAt(RepoPaths.blobPath(identHash, entry.contentHash), bytes);

      // Let the availability and service providers observe the fresh blob so
      // names re-resolve through the lookup chain.
      ref
        ..invalidate(localizationDbAvailabilityProvider(locale))
        ..invalidate(localizationDbServiceProvider);
      state = const LocaleDbDownloadState.ready();
    } on Object catch (e, st) {
      warning("Locale DB download failed for $locale: $e", stackTrace: st);
      state = const LocaleDbDownloadState.failed(reason: LocaleDbDownloadFailureReason.unknown);
    }
  }
}
