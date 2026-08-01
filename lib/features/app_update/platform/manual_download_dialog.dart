import "dart:async";

import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/features/app_update/platform/update_platform.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_notifier.dart";
import "package:eve_fit_assistant/features/app_update/update_dialog_shared.dart";
import "package:eve_fit_assistant/storage/repo/models/remote_app_release.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart" show remoteCatalogServiceProvider;
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:url_launcher/url_launcher.dart";

/// Update dialog for platforms without in-app download/install support
/// (e.g. Linux). Mirrors the Android update dialog layout, but replaces the
/// download session with a list of manual download targets resolved from the
/// platform's artifacts.
class ManualReleaseDownloadDialog extends ConsumerWidget {
  const ManualReleaseDownloadDialog({required this.release, super.key});

  final RemoteAppRelease release;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adapter = ref.watch(appUpdatePlatformAdapterProvider);
    final targets = adapter.downloadTargets(release.index);

    return AppDialog(
      title: context.l10n.versionPageUpdateAvailable(version: release.version),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.appReleaseUpdateManualDownloadBody),
              const SizedBox(height: 12),
              UpdateVersionSummary(release: release),
              const SizedBox(height: 16),
              Text(
                context.l10n.appReleaseUpdateDownloadTargetsTitle,
                style: context.theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              for (final target in targets) _DownloadTargetTile(target: target),
              const SizedBox(height: 16),
              Text(
                context.l10n.appReleaseUpdateWhatsNew,
                style: context.theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              UpdateReleaseNotes(release: release),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(appVersionStateServiceProvider.notifier).acknowledgeRelease(release.releaseId);
            Navigator.of(context).pop();
          },
          child: Text(context.l10n.appReleaseUpdateAcknowledge),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.close),
        ),
      ],
    );
  }
}

/// A single manual download target row: variant label, size, and actions to
/// copy the download link or open it in a browser.
class _DownloadTargetTile extends ConsumerWidget {
  const _DownloadTargetTile({required this.target});

  final ReleaseDownloadTarget target;

  String _variantLabel(BuildContext context) => switch (target.variant) {
    "appimage" => context.l10n.appReleaseUpdateDownloadTargetAppImage,
    "native" => context.l10n.appReleaseUpdateDownloadTargetNative,
    _ => target.variant,
  };

  Uri _downloadUri(WidgetRef ref) => target.downloadUri(ref.read(remoteCatalogServiceProvider));

  Future<void> _copyLink(BuildContext context, WidgetRef ref) async {
    final uri = _downloadUri(ref);
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.appReleaseUpdateDownloadLinkCopied)));
  }

  Future<void> _openLink(BuildContext context, WidgetRef ref) async {
    final uri = _downloadUri(ref);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.save_alt_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _variantLabel(context),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  formatUpdateBytes(target.size),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => unawaited(_copyLink(context, ref)),
            icon: const Icon(Icons.link),
            tooltip: context.l10n.appReleaseUpdateCopyDownloadLink,
          ),
          IconButton(
            onPressed: () => unawaited(_openLink(context, ref)),
            icon: const Icon(Icons.open_in_new),
            tooltip: context.l10n.appReleaseUpdateOpenDownloadLink,
          ),
        ],
      ),
    );
  }
}
