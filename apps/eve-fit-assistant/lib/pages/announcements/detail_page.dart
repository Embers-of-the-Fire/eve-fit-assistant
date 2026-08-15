import "package:eve_fit_assistant/constant/colors.dart";
import "package:eve_fit_assistant/features/announcements/models/models.dart";
import "package:eve_fit_assistant/features/announcements/remote/remote.dart";
import "package:eve_fit_assistant/features/announcements/repository/repository.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/version.dart";
import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

final announcementBodyProvider = FutureProvider.family<String?, String>((
  Ref ref,
  String bodyHash,
) async {
  if (bodyHash.isEmpty) return null;
  final cached = await AnnouncementBodyCache.get(bodyHash);
  if (cached != null) return cached;

  final repo = ref.read(announcementRepositoryProvider);
  final body = await repo.fetchAnnouncementBody(bodyHash);
  if (body != null) {
    await AnnouncementBodyCache.put(bodyHash, body);
  }
  return body;
});

/// Full-page detail view (standalone, with Scaffold + AppBar).
class AnnouncementDetailPage extends ConsumerWidget {
  const AnnouncementDetailPage({required this.record, super.key});

  final AnnouncementRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: Text(record.title)),
    body: AnnouncementDetailContent(record: record),
  );
}

/// Reusable detail content widget (no Scaffold) — used by the hub page's
/// detail pane and [AnnouncementDetailPage].
class AnnouncementDetailContent extends ConsumerWidget {
  const AnnouncementDetailContent({required this.record, super.key});

  final AnnouncementRecord? record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (record == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.announcementNoEntries,
            textAlign: TextAlign.center,
            style: context.theme.textTheme.titleMedium,
          ),
        ),
      );
    }

    final appVer = ref
        .watch(appVersionProvider)
        .when(data: (v) => v, loading: () => null, error: (_, _) => null);
    final showMinVerWarning =
        record!.minAppVersion != null &&
        appVer != null &&
        isAppVersionBelow(appVer, record!.minAppVersion!);

    final dateText = DateFormat.yMMMMd(
      context.locale.toString(),
    ).format(record!.publishedAt.toLocal());
    final colorScheme = context.theme.colorScheme;

    final bodyAsync = record!.bodyHash.isNotEmpty
        ? ref.watch(announcementBodyProvider(record!.bodyHash))
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(record!.title, style: context.theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                dateText,
                style: context.theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _AnnouncementDetailBadge(
                    label: record!.source == AnnouncementEntrySource.bundled
                        ? context.l10n.announcementSourceBundled
                        : context.l10n.announcementSourceRemote,
                    icon: record!.source == AnnouncementEntrySource.bundled
                        ? Icons.phone_android_outlined
                        : Icons.cloud_outlined,
                  ),
                  if (record!.appVersion != null)
                    _AnnouncementDetailBadge(
                      label: context.l10n.documentVersionBadge(version: record!.appVersion!),
                      icon: Icons.sell_outlined,
                    ),
                ],
              ),
              if (showMinVerWarning) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        context.l10n.documentMinAppVerWarning(version: record!.minAppVersion!),
                        style: context.theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 24),
        Expanded(
          child: bodyAsync == null
              ? const SizedBox.shrink()
              : bodyAsync.when(
                  data: (body) {
                    if (body == null || body.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4, right: 20, bottom: 10, left: 20),
                      child: Markdown(
                        data: body,
                        padding: EdgeInsets.zero,
                        softLineBreak: true,
                        styleSheet: markdownDarkStyleSheet,
                        onTapLink: openMarkdownLinkExternally,
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: context.theme.colorScheme.error,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.announcementBodyLoadError,
                            style: context.theme.textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              ref.invalidate(announcementBodyProvider(record!.bodyHash));
                            },
                            child: Text(context.l10n.announcementBodyLoadRetry),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _AnnouncementDetailBadge extends StatelessWidget {
  const _AnnouncementDetailBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 6),
            Text(label, style: context.theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
