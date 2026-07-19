import "package:eve_fit_assistant/features/app_update/providers.dart";
import "package:eve_fit_assistant/storage/repo/models/remote_app_release.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Copies the manual-download URL for [release] to the clipboard and shows a
/// confirmation snackbar.
///
/// The URL points at the content-addressed artifact on the configured remote
/// origin and can be opened in a browser when the in-app download or install
/// is not usable.
Future<void> copyReleaseDownloadLink(
  BuildContext context,
  WidgetRef ref,
  RemoteAppRelease release,
) async {
  final service = ref.read(appUpdateServiceProvider);
  final uri = await service.resolveDownloadUri(release.index.android);
  if (!context.mounted) return;

  if (uri == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.appReleaseUpdateNoArtifact)));
    return;
  }

  await Clipboard.setData(ClipboardData(text: uri.toString()));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.appReleaseUpdateDownloadLinkCopied)));
}
