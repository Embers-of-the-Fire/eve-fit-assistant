import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/constant/colors.dart";
import "package:eve_fit_assistant/features/announcements/models/models.dart";
import "package:eve_fit_assistant/features/announcements/repository/repository.dart";
import "package:eve_fit_assistant/features/app_update/app_update_service.dart";
import "package:eve_fit_assistant/features/app_update/app_update_status.dart";
import "package:eve_fit_assistant/features/app_update/download_link.dart";
import "package:eve_fit_assistant/features/app_update/providers.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_notifier.dart";
import "package:eve_fit_assistant/pages/announcements/detail_page.dart";
import "package:eve_fit_assistant/pages/router.dart" show AnnouncementFeedRoute;
import "package:eve_fit_assistant/storage/repo/models/remote_app_release.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/version.dart";
import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fpdart/fpdart.dart";

/// Resolves the best-matching Android artifact for a release, exposing the
/// download size shown in the update dialog. `null` when the release has no
/// usable artifact for this device.
final appUpdateArtifactProvider = FutureProvider.family<AppUpdateArtifact?, RemoteAppRelease>((
  ref,
  release,
) async {
  if (!release.index.hasAndroid()) return null;
  final artifacts = release.index.android;
  if (!artifacts.hasGeneral()) return null;
  final service = ref.watch(appUpdateServiceProvider);
  final result = await service.resolveArtifact(artifacts);
  return result.toNullable();
});

/// Finds the release-note announcement record whose `appVersion` matches the
/// given release version. `null` when no matching note is published yet.
final appReleaseNoteProvider = FutureProvider.family<AnnouncementRecord?, String>((
  ref,
  version,
) async {
  final records = await ref.watch(announcementVersionFeedProvider.future);
  for (final record in records) {
    final appVersion = record.appVersion;
    if (appVersion != null && _isSameVersion(appVersion, version)) return record;
  }
  return null;
});

bool _isSameVersion(String a, String b) {
  String normalize(String version) {
    var value = stripBuildNumber(version).trim();
    if (value.toLowerCase().startsWith("v")) value = value.substring(1);
    return value;
  }

  return compareAppVersions(normalize(a), normalize(b)) == 0;
}

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
  ProviderSubscription<AsyncValue<Option<RemoteAppRelease>>>? _subscription;
  ProviderSubscription<AppUpdateStatus>? _silentSubscription;

  @override
  void initState() {
    super.initState();
    // Listen manually with fireImmediately so a release that resolved before
    // this gate mounted still triggers the dialog, while later updates keep
    // being delivered. Registered in initState because ref.listen is not
    // available there.
    _subscription = ref.listenManual(
      availableAppReleaseProvider,
      fireImmediately: true,
      (_, next) => next.whenData((option) {
        final release = option.toNullable();
        if (release == null) return;
        if (_shownReleaseId == release.releaseId || _isShowing) return;

        if (ref.read(appSettingServiceProvider).silentUpdate) {
          // Silent strategy: no update dialog. Download in the background and
          // only surface a confirmation once the artifact is ready. Mark the
          // release as handled immediately so provider re-emissions during
          // the download never retrigger the flow.
          _shownReleaseId = release.releaseId;
          WidgetsBinding.instance.addPostFrameCallback((_) => _startSilentUpdate(release));
          return;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_showDialog(release)));
      }),
    );
  }

  @override
  void dispose() {
    _subscription?.close();
    _silentSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _showDialog(RemoteAppRelease release) async {
    if (!mounted || _isShowing) return;
    _isShowing = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppReleaseUpdateDialog(release: release),
    );

    if (mounted) {
      // Acknowledging the APK update dialog (or completing the install) also
      // counts as having "seen" this app version, which suppresses the
      // workspace version-bump card for the same release.
      ref.read(appVersionStateServiceProvider.notifier).acknowledgeVersion(release.version);
      _shownReleaseId = release.releaseId;
      _isShowing = false;
    }
  }

  void _startSilentUpdate(RemoteAppRelease release) {
    if (!mounted) return;

    // The subscription must stay open for the whole silent flow: it is the
    // only listener keeping the auto-dispose controller (and its
    // readyToInstall state) alive while the confirmation dialog is shown.
    _silentSubscription?.close();
    _silentSubscription = ref.listenManual(
      appUpdateControllerProvider(release),
      fireImmediately: true,
      (_, next) => unawaited(_onSilentStatus(release, next)),
    );

    final current = ref.read(appUpdateControllerProvider(release));
    if (current is AppUpdateStatusIdle || current is AppUpdateStatusFailed) {
      unawaited(ref.read(appUpdateControllerProvider(release).notifier).download());
    }
    // A readyToInstall state is already handled by the fireImmediately
    // dispatch above; in-progress states are left to finish.
  }

  Future<void> _onSilentStatus(RemoteAppRelease release, AppUpdateStatus status) async {
    switch (status) {
      case AppUpdateStatusReadyToInstall():
        // Only retire the subscription once the install prompt has actually
        // been displayed. When the prompt was skipped (gate unmounted or
        // another dialog is visible), keep listening: install() can drop
        // back to readyToInstall, and without a listener the release would
        // no longer be actionable from this gate.
        final prompted = await _promptSilentInstall(release);
        if (!prompted) return;
        _silentSubscription?.close();
        _silentSubscription = null;
      case AppUpdateStatusFailed():
        // Silent strategy never surfaces download errors; the update stays
        // reachable from the version page check tile.
        _silentSubscription?.close();
        _silentSubscription = null;
      default:
    }
  }

  /// Shows the silent install confirmation. Returns whether the dialog was
  /// actually displayed; callers use this to decide if the controller
  /// subscription is still needed.
  Future<bool> _promptSilentInstall(RemoteAppRelease release) async {
    if (!mounted || _isShowing) return false;
    _isShowing = true;

    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.appReleaseSilentUpdateReadyTitle,
      content: Text(context.l10n.appReleaseSilentUpdateReadyMessage(version: release.version)),
    );

    if (!mounted) return true;
    if (confirmed) {
      await ref.read(appUpdateControllerProvider(release).notifier).install();
      if (!mounted) return true;
      ref.read(appVersionStateServiceProvider.notifier).acknowledgeVersion(release.version);
    } else {
      // Postponed: acknowledge so the silent flow does not retrigger on the
      // next launch; the version page check tile still offers the update.
      ref.read(appVersionStateServiceProvider.notifier).acknowledgeRelease(release.releaseId);
    }
    _isShowing = false;
    return true;
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
        AppUpdateStatusIdle() => _UpdateIdleContent(release: release),
        AppUpdateStatusDownloading(:final receivedBytes, :final totalBytes) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _UpdateVersionSummary(release: release),
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
                  ? context.l10n.appReleaseUpdateVerifying
                  : context.l10n.appReleaseUpdateInstalling,
              style: context.theme.textTheme.bodySmall,
            ),
          ],
        ),
        AppUpdateStatusReadyToInstall() => Text(context.l10n.appReleaseUpdateInstall),
        AppUpdateStatusFailed(:final message, :final canRetry, :final permissionRequired) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (canRetry && permissionRequired) ...[
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
        IconButton(
          onPressed: () => unawaited(copyReleaseDownloadLink(context, ref, release)),
          icon: const Icon(Icons.link),
          tooltip: context.l10n.appReleaseUpdateCopyDownloadLink,
        ),
        TextButton(
          onPressed: () {
            ref.read(appVersionStateServiceProvider.notifier).acknowledgeRelease(release.releaseId);
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
        IconButton(
          onPressed: () => unawaited(copyReleaseDownloadLink(context, ref, release)),
          icon: const Icon(Icons.link),
          tooltip: context.l10n.appReleaseUpdateCopyDownloadLink,
        ),
        TextButton(
          onPressed: () {
            ref.read(appVersionStateServiceProvider.notifier).acknowledgeRelease(release.releaseId);
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
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return "${bytes}B";
  if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)}KB";
  return "${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB";
}

/// Version + download-size summary shown in the update dialog.
class _UpdateVersionSummary extends ConsumerWidget {
  const _UpdateVersionSummary({required this.release});

  final RemoteAppRelease release;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final installedVersion = ref.watch(appVersionProvider).value;
    final artifact = ref.watch(appUpdateArtifactProvider(release)).value;

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 16),
          Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row(
          context.l10n.appReleaseUpdateCurrentVersion,
          installedVersion == null ? "…" : "v$installedVersion",
        ),
        row(context.l10n.appReleaseUpdateNewVersion, "v${release.version}"),
        if (artifact != null)
          row(context.l10n.appReleaseUpdateDownloadSize, _formatBytes(artifact.size)),
      ],
    );
  }
}

/// Idle-state content: version summary plus the inline "what's new" section.
///
/// The fixed width is required: [AlertDialog] measures the intrinsic width of
/// its content, which would otherwise descend into the shrink-wrapping
/// markdown viewport and throw. A tight width constraint short-circuits that
/// measurement (same pattern as `AnnouncementDialog`).
class _UpdateIdleContent extends ConsumerWidget {
  const _UpdateIdleContent({required this.release});

  final RemoteAppRelease release;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;

    return SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.appReleaseUpdateDialogBody),
          const SizedBox(height: 12),
          _UpdateVersionSummary(release: release),
          const SizedBox(height: 16),
          Text(
            context.l10n.appReleaseUpdateWhatsNew,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Flexible(child: _UpdateReleaseNotes(release: release)),
        ],
      ),
    );
  }
}

/// Renders the release note matching the new version, loading its markdown
/// body on demand, with a shortcut to the full release-notes page.
class _UpdateReleaseNotes extends ConsumerWidget {
  const _UpdateReleaseNotes({required this.release});

  final RemoteAppRelease release;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final noteAsync = ref.watch(appReleaseNoteProvider(release.version));

    final loading = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text(context.l10n.appReleaseUpdateNotesLoading, style: theme.textTheme.bodySmall),
        ],
      ),
    );

    final unavailable = Text(
      context.l10n.appReleaseUpdateNotesUnavailable,
      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );

    return noteAsync.when(
      loading: () => loading,
      error: (_, _) => unavailable,
      data: (record) {
        if (record == null) return unavailable;

        final fallbackText = record.summary.isNotEmpty ? record.summary : null;
        final bodyAsync = record.bodyHash.isNotEmpty
            ? ref.watch(announcementBodyProvider(record.bodyHash))
            : null;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: bodyAsync == null
                    ? (fallbackText != null
                          ? SingleChildScrollView(
                              child: Text(fallbackText, style: theme.textTheme.bodySmall),
                            )
                          : unavailable)
                    : bodyAsync.when(
                        loading: () => loading,
                        error: (_, _) => fallbackText != null
                            ? SingleChildScrollView(
                                child: Text(fallbackText, style: theme.textTheme.bodySmall),
                              )
                            : unavailable,
                        data: (body) {
                          if (body == null || body.isEmpty) {
                            return fallbackText != null
                                ? SingleChildScrollView(
                                    child: Text(fallbackText, style: theme.textTheme.bodySmall),
                                  )
                                : unavailable;
                          }
                          return SingleChildScrollView(
                            child: MarkdownBody(
                              data: body,
                              softLineBreak: true,
                              styleSheet: markdownDarkStyleSheet,
                              onTapLink: openMarkdownLinkExternally,
                            ),
                          );
                        },
                      ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(context.router.push(AnnouncementFeedRoute(initialRecordId: record.id)));
                },
                child: Text(context.l10n.appReleaseUpdateViewFullNotes),
              ),
            ),
          ],
        );
      },
    );
  }
}
