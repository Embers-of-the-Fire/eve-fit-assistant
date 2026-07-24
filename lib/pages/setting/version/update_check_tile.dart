import "dart:async";

import "package:eve_fit_assistant/features/app_update/app_update_gate.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart"
    show appReleaseCheckStatusProvider, repoServiceProvider;
import "package:eve_fit_assistant/storage/repo/release_sync.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart" show appSettingServiceProvider;
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// A tile on the version page that reports the app update status and lets the
/// user trigger a fresh check against the remote release index.
///
/// Shows one of three primary states:
/// - a newer release is available (tap to open the update dialog),
/// - the app is already on the latest release,
/// - the installed version is newer than the latest remote release
///   (unexpected, but surfaced for transparency).
class AppUpdateCheckTile extends ConsumerStatefulWidget {
  const AppUpdateCheckTile({super.key});

  @override
  ConsumerState<AppUpdateCheckTile> createState() => _AppUpdateCheckTileState();
}

class _AppUpdateCheckTileState extends ConsumerState<AppUpdateCheckTile> {
  bool _checking = false;
  bool _syncFailed = false;

  Future<void> _check() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _syncFailed = false;
    });
    try {
      final settings = ref.read(appSettingServiceProvider);
      final channel = settings.remoteContent.channel;
      if (settings.remoteContent.enabled && channel.isNotEmpty) {
        // Sync the generation metadata first so the release pointer cache is
        // refreshed before the status provider re-reads it. If the sync fails
        // the cached pointer is stale, so surface the failure instead of
        // reporting a status derived from outdated data.
        final syncResult = await ref.read(repoServiceProvider).syncChannelGeneration(channel);
        if (syncResult.isLeft()) {
          if (mounted) setState(() => _syncFailed = true);
          return;
        }
      }
      ref.invalidate(appReleaseCheckStatusProvider);
      // Await the fresh check so the spinner reflects real progress; failures
      // surface through the provider as AsyncError. The timeout bounds the
      // wait since failed providers are retried automatically with backoff.
      await ref
          .read(appReleaseCheckStatusProvider.future)
          .then((_) => null)
          .catchError((Object _) => null)
          .timeout(const Duration(seconds: 20), onTimeout: () => null);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(appReleaseCheckStatusProvider);
    final status = statusAsync.value;
    final busy = _checking || statusAsync.isLoading;
    final hasError = statusAsync.hasError || _syncFailed;

    if (status is ReleaseCheckUpdateAvailable) {
      return _UpdateAvailableCard(
        status: status,
        onTap: () async {
          await showDialog<void>(
            context: context,
            builder: (context) => AppReleaseUpdateDialog(release: status.release),
          );
        },
      );
    }

    final theme = context.theme;
    final l10n = context.l10n;

    final subtitle = switch (status) {
      _ when busy => l10n.versionPageCheckUpdateChecking,
      _ when hasError => l10n.versionPageCheckUpdateFailed,
      ReleaseCheckUpToDate() => l10n.versionPageCheckUpdateUpToDate,
      ReleaseCheckAheadOfRemote(:final remoteVersion) => l10n.versionPageCheckUpdateAhead(
        version: remoteVersion,
      ),
      _ => l10n.versionPageCheckUpdateUnavailable,
    };

    final trailing = busy
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
          )
        : hasError
        ? Text(
            l10n.versionPageCheckUpdateActionRetry,
            style: TextStyle(color: theme.colorScheme.error),
          )
        : Text(
            l10n.versionPageCheckUpdateActionCheck,
            style: TextStyle(color: theme.colorScheme.primary),
          );

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: busy ? null : () => unawaited(_check()),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                status is ReleaseCheckAheadOfRemote ? Icons.warning_amber_outlined : Icons.update,
                color: status is ReleaseCheckAheadOfRemote
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.versionPageCheckUpdateTitle,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: status is ReleaseCheckAheadOfRemote || hasError
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _UpdateAvailableCard extends StatelessWidget {
  const _UpdateAvailableCard({required this.status, required this.onTap});

  final ReleaseCheckUpdateAvailable status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Card.filled(
      color: theme.colorScheme.primaryContainer,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.system_update_alt, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.versionPageUpdateAvailable(version: status.release.version),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.versionPageUpdateManualDownloadHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}
