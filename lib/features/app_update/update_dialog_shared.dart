import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/constant/colors.dart";
import "package:eve_fit_assistant/features/announcements/models/models.dart";
import "package:eve_fit_assistant/features/announcements/repository/repository.dart";
import "package:eve_fit_assistant/features/app_update/app_update_service.dart";
import "package:eve_fit_assistant/features/app_update/platform/update_platform.dart";
import "package:eve_fit_assistant/features/app_update/providers.dart";
import "package:eve_fit_assistant/pages/announcements/detail_page.dart";
import "package:eve_fit_assistant/pages/router.dart" show AnnouncementFeedRoute;
import "package:eve_fit_assistant/storage/repo/models/remote_app_release.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/version.dart";
import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

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

String formatUpdateBytes(int bytes) {
  if (bytes < 1024) return "${bytes}B";
  if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)}KB";
  return "${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB";
}

/// Version + download-size summary shown in the update dialog.
class UpdateVersionSummary extends ConsumerWidget {
  const UpdateVersionSummary({required this.release, super.key});

  final RemoteAppRelease release;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final installedVersion = ref.watch(appVersionProvider).value;
    final selfUpdate = ref.watch(
      appUpdatePlatformAdapterProvider.select((adapter) => adapter.supportsSelfUpdate),
    );
    final artifact = selfUpdate ? ref.watch(appUpdateArtifactProvider(release)).value : null;

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
          row(context.l10n.appReleaseUpdateDownloadSize, formatUpdateBytes(artifact.size)),
      ],
    );
  }
}

/// Renders the release note matching the new version, loading its markdown
/// body on demand, with a shortcut to the full release-notes page.
class UpdateReleaseNotes extends ConsumerWidget {
  const UpdateReleaseNotes({required this.release, super.key});

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
            ConstrainedBox(
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
