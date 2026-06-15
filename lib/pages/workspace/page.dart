import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/badge/notification_dot.dart";
import "package:eve_fit_assistant/components/card/homepage_link_card.dart";
import "package:eve_fit_assistant/features/documents/repository.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class _WorkspaceShortcutItem {
  const _WorkspaceShortcutItem({required this.title, required this.icon, required this.onTap});

  final String title;
  final IconData icon;
  final void Function() onTap;
}

class WorkspacePage extends ConsumerWidget {
  const WorkspacePage({super.key});

  static const int _updatesCardIndex = 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <_WorkspaceShortcutItem>[
      _WorkspaceShortcutItem(
        title: context.l10n.workspaceTabActionCreateFitName,
        icon: Icons.add_circle_outline,
        onTap: () async {
          if (context.mounted) {
            unawaited(context.router.push(const FitCreationRoute()));
          }
        },
      ),
      _WorkspaceShortcutItem(
        title: context.l10n.workspaceTabAnnouncementTitle,
        icon: Icons.campaign_outlined,
        onTap: () => context.router.push(const AnnouncementRoute()),
      ),
      _WorkspaceShortcutItem(
        title: context.l10n.workspaceTabReportTitle,
        icon: Icons.feedback_outlined,
        onTap: () => context.router.push(const ReportFeedbackRoute()),
      ),
      _WorkspaceShortcutItem(
        title: context.l10n.settingTileAppSettingsTitle,
        icon: Icons.settings_outlined,
        onTap: () => context.router.push(const AppSettingsRoute()),
      ),
    ];

    final unreadCount = ref.watch(unreadAnnouncementCountProvider);

    final grid = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final it = items[index];
              Widget card = HomepageLinkCard(title: it.title, icon: it.icon, onTap: it.onTap);
              if (index == _updatesCardIndex && unreadCount > 0) {
                card = NotificationDot(count: unreadCount, badgeRadius: 13, child: card);
              }
              return card;
            },
          ),
        ),
      ),
    );

    final hasVersionBump = ref.watch(hasVersionBumpProvider);
    if (!hasVersionBump) {
      return grid;
    }

    return Column(
      children: [
        _buildVersionBumpCard(context, ref),
        Expanded(child: grid),
      ],
    );
  }

  Widget _buildVersionBumpCard(BuildContext context, WidgetRef ref) {
    final appVersion = ref
        .watch(appVersionProvider)
        .when(data: (v) => v, loading: () => "", error: (_, _) => "");
    final unreadVersionCount = ref.watch(unreadVersionCountProvider);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: InkWell(
        onTap: () {
          ref.read(documentReadServiceProvider).acknowledgeVersionBump(appVersion);
          unawaited(context.router.push(const VersionRoute()));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.new_releases, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.versionBumpCardTitle(version: appVersion),
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      unreadVersionCount > 0
                          ? context.l10n.versionBumpCardSubtitle(count: unreadVersionCount)
                          : context.l10n.versionBumpCardSubtitleFallback,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: context.l10n.versionBumpCardCloseTooltip,
                onPressed: () {
                  ref.read(documentReadServiceProvider).acknowledgeVersionBump(appVersion);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
