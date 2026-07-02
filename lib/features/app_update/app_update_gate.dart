import "dart:async";

import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/release_sync.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fpdart/fpdart.dart";

/// Displays a non-blocking dialog when a newer app release is available.
///
/// The only user action at this stage is to acknowledge the release. Download
/// and install behavior will be defined in a later iteration.
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
      builder: (context) => _AppReleaseUpdateDialog(
        release: release,
        onAcknowledge: () {
          ref.read(availableAppReleaseProvider.notifier).acknowledge(release.releaseId);
          Navigator.of(context).pop();
        },
      ),
    );

    if (mounted) {
      _shownReleaseId = release.releaseId;
      _isShowing = false;
    }
  }
}

class _AppReleaseUpdateDialog extends StatelessWidget {
  const _AppReleaseUpdateDialog({required this.release, required this.onAcknowledge});

  final RemoteAppRelease release;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) => AppDialog(
    title: context.l10n.versionPageUpdateAvailable(version: release.version),
    content: Text(context.l10n.appReleaseUpdateDialogBody),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.cancel)),
      ElevatedButton(
        onPressed: onAcknowledge,
        child: Text(context.l10n.appReleaseUpdateAcknowledge),
      ),
    ],
  );
}
