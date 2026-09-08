import "dart:async";

import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/features/locale_switch/locale_db_download_controller.dart";
import "package:eve_fit_assistant/features/locale_switch/locale_db_download_state.dart";
import "package:eve_fit_assistant/pages/setting/data/data_update_dialog.dart";
import "package:eve_fit_assistant/storage/repo/localization_db.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Evaluates the localization database availability of [locale] — called
/// after [locale] was persisted as the active app locale — and offers the
/// matching locale-switch flow (spec §5.2):
///
/// - `downloadable(size)` → confirmation dialog naming the locale and the
///   download size, then a non-dismissible progress dialog; failure offers
///   retry. Cancel leaves the locale switched with placeholders rendering.
/// - `updateRequired` → informational dialog routing into the existing
///   data-update flow.
/// - `available` → no dialog; names simply re-resolve.
Future<void> offerLocaleLocalizationDb(BuildContext context, WidgetRef ref, Locale locale) async {
  // No active checkout (e.g. the welcome wizard's language step, which
  // precedes provisioning): nothing to evaluate; provisioning downloads the
  // chosen locale's database eagerly (R2).
  if (ref.read(activeCheckoutIdProvider).toNullable() == null) return;

  final LocalizationDbAvailability availability;
  try {
    availability = await ref.read(localizationDbAvailabilityProvider(locale.name).future);
  } on Object {
    return; // availability resolution is best-effort; the §5.3 indicator stays
  }
  if (!context.mounted) return;
  // A later locale selection supersedes this flow: discard the availability
  // result when [locale] is no longer the active configured locale.
  if (ref.read(localeProvider) != locale) return;

  switch (availability) {
    case LocalizationDbAvailable():
      return;
    case LocalizationDbDownloadable(:final sizeBytes):
      final confirmed = await showConfirmDialog(
        context,
        title: context.l10n.localeDbDownloadTitle(locale: locale.display),
        content: Text(context.l10n.localeDbDownloadBody(size: _formatSize(sizeBytes))),
      );
      if (!confirmed || !context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => LocaleDbDownloadDialog(locale: locale.name),
      );
    case LocalizationDbUpdateRequired():
      await showDialog<void>(
        context: context,
        builder: (_) => _LocaleDbUpdateRequiredDialog(locale: locale),
      );
  }
}

String _formatSize(int bytes) {
  if (bytes < 1024) return "$bytes B";
  if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
  return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
}

/// Non-dismissible progress dialog for a per-locale localization database
/// download; failure offers retry (spec §5.2).
class LocaleDbDownloadDialog extends ConsumerWidget {
  const LocaleDbDownloadDialog({required this.locale, super.key});

  /// The locale whose per-locale database is being downloaded.
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localeDbDownloadControllerProvider(locale));

    ref.listen(localeDbDownloadControllerProvider(locale), (_, next) {
      if (next is LocaleDbDownloadReady && context.mounted) {
        Navigator.of(context).pop();
      }
    });

    if (state is LocaleDbDownloadIdle) {
      // Kick off the download on first build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(ref.read(localeDbDownloadControllerProvider(locale).notifier).download());
      });
    }

    final l10n = context.l10n;
    final downloading = state is LocaleDbDownloading ? state : null;
    final failed = state is LocaleDbDownloadFailed ? state : null;

    return PopScope(
      canPop: downloading == null,
      child: AlertDialog(
        title: Text(l10n.localeDbDownloadTitle(locale: locale)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (failed == null) ...[
              LinearProgressIndicator(
                value: downloading != null && downloading.totalBytes > 0
                    ? downloading.downloadedBytes / downloading.totalBytes
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.localeDbDownloadProgress(
                  downloaded: _formatSize(downloading?.downloadedBytes ?? 0),
                  total: _formatSize(downloading?.totalBytes ?? 0),
                ),
              ),
            ] else
              Text(l10n.localeDbDownloadFailureBody),
          ],
        ),
        actions: failed != null
            ? [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
                ElevatedButton(
                  onPressed: () => unawaited(
                    ref.read(localeDbDownloadControllerProvider(locale).notifier).download(),
                  ),
                  child: Text(l10n.dataUpdateActionRetry),
                ),
              ]
            : null,
      ),
    );
  }
}

class _LocaleDbUpdateRequiredDialog extends ConsumerWidget {
  const _LocaleDbUpdateRequiredDialog({required this.locale});

  final Locale locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.localeDbUpdateRequiredTitle(locale: locale.display)),
      content: Text(l10n.localeDbUpdateRequiredBody),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            final checkoutId = ref.read(activeCheckoutIdProvider).toNullable();
            if (checkoutId != null && context.mounted) {
              unawaited(showCheckoutDataUpdateOperationDialog(context, ref, checkoutId));
            }
          },
          child: Text(l10n.dataUpdateActionUpdate),
        ),
      ],
    );
  }
}
