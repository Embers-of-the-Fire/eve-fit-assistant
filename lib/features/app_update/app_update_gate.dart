import "dart:async";

import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/features/announcements/state/announcement_state_notifier.dart";
import "package:eve_fit_assistant/features/app_update/app_update_status.dart";
import "package:eve_fit_assistant/features/app_update/providers.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/release_sync.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fpdart/fpdart.dart";

/// Displays a non-blocking dialog when a newer app release is available.
///
/// Listens to [availableAppReleaseProvider] continuously so the dialog is shown
/// even when the release check completes after the first frame (for example,
/// after the startup background sync finishes).
class AppReleaseUpdateGate extends ConsumerStatefulWidget {
  const AppReleaseUpdateGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppReleaseUpdateGate> createState() => _AppReleaseUpdateGateState();
}

class _AppReleaseUpdateGateState extends ConsumerState<AppReleaseUpdateGate> {
  String? _shownReleaseId;
  bool _isShowing = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Option<RemoteAppRelease>>>(
      availableAppReleaseProvider,
      (_, next) => next.whenData((option) {
        final release = option.toNullable();
        if (release == null) return;
        if (_shownReleaseId == release.releaseId || _isShowing) return;

        WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_showDialog(release)));
      }),
    );

    return widget.child;
  }

  Future<void> _showDialog(RemoteAppRelease release) async {
    if (!mounted || _isShowing) return;
    _isShowing = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppReleaseUpdateDialog(release: release),
    );

    if (mounted) {
      _shownReleaseId = release.releaseId;
      _isShowing = false;
    }
  }
}

class AppReleaseUpdateDialog extends ConsumerWidget {
  const AppReleaseUpdateDialog({required this.release, super.key});

  final RemoteAppRelease release;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(appUpdateControllerProvider(release));

    return AppDialog(
      title: context.l10n.versionPageUpdateAvailable(version: release.version),
      content: _buildContent(context, ref, status),
      actions: _buildActions(context, ref, status),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, AppUpdateStatus status) =>
      switch (status) {
        AppUpdateStatusIdle() => Text(context.l10n.appReleaseUpdateDialogBody),
        AppUpdateStatusDownloading(:final receivedBytes, :final totalBytes) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.appReleaseUpdateDialogBody),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: totalBytes > 0 ? receivedBytes / totalBytes : null),
            const SizedBox(height: 8),
            Text(
              context.l10n.appReleaseUpdateDownloadProgress(
                received: _formatBytes(receivedBytes),
                total: _formatBytes(totalBytes),
              ),
              style: context.theme.textTheme.bodySmall,
            ),
          ],
        ),
        AppUpdateStatusVerifying() || AppUpdateStatusInstalling() => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.appReleaseUpdateDialogBody),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              status is AppUpdateStatusVerifying
                  ? "Verifying…"
                  : context.l10n.appReleaseUpdateInstalling,
              style: context.theme.textTheme.bodySmall,
            ),
          ],
        ),
        AppUpdateStatusReadyToInstall() => Text(context.l10n.appReleaseUpdateInstall),
        AppUpdateStatusFailed(:final message, :final canRetry) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (canRetry && message == context.l10n.appReleaseUpdatePermissionRequired) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => unawaited(
                  ref.read(appUpdateControllerProvider(release).notifier).openPermissionSettings(),
                ),
                icon: const Icon(Icons.open_in_new),
                label: Text(context.l10n.appReleaseUpdateOpenSettings),
              ),
            ],
          ],
        ),
      };

  List<Widget> _buildActions(BuildContext context, WidgetRef ref, AppUpdateStatus status) {
    final controller = ref.read(appUpdateControllerProvider(release).notifier);

    return switch (status) {
      AppUpdateStatusIdle() => [
        TextButton(
          onPressed: () {
            ref
                .read(announcementStateServiceProvider.notifier)
                .acknowledgeRelease(release.releaseId);
            Navigator.of(context).pop();
          },
          child: Text(context.l10n.appReleaseUpdateAcknowledge),
        ),
        ElevatedButton(
          onPressed: () => unawaited(controller.download()),
          child: Text(context.l10n.appReleaseUpdateDownload),
        ),
      ],
      AppUpdateStatusDownloading() || AppUpdateStatusVerifying() || AppUpdateStatusInstalling() => [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.appReleaseUpdateCancel),
        ),
      ],
      AppUpdateStatusReadyToInstall() => [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.appReleaseUpdateCancel),
        ),
        ElevatedButton(
          onPressed: () => unawaited(controller.install()),
          child: Text(context.l10n.appReleaseUpdateInstall),
        ),
      ],
      AppUpdateStatusFailed(:final canRetry) => [
        TextButton(
          onPressed: () {
            ref
                .read(announcementStateServiceProvider.notifier)
                .acknowledgeRelease(release.releaseId);
            Navigator.of(context).pop();
          },
          child: Text(context.l10n.appReleaseUpdateAcknowledge),
        ),
        if (canRetry)
          ElevatedButton(
            onPressed: controller.retry,
            child: Text(context.l10n.appReleaseUpdateRetry),
          ),
      ],
    };
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return "${bytes}B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)}KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB";
  }
}
