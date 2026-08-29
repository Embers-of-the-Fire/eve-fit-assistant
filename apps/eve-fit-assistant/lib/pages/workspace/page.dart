import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/badge/notification_dot.dart";
import "package:eve_fit_assistant/components/card/homepage_link_card.dart";
import "package:eve_fit_assistant/config/engine_availability.dart";
import "package:eve_fit_assistant/constant/links.dart";
import "package:eve_fit_assistant/features/announcements/repository/repository.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_notifier.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/pages/workspace/data_update_banner.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class _WorkspaceShortcutItem {
  const _WorkspaceShortcutItem({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isUpdatesCard = false,
  });

  final String title;
  final IconData icon;
  final void Function() onTap;

  /// Whether this card carries the unread-announcement badge.
  final bool isUpdatesCard;
}

class WorkspacePage extends ConsumerWidget {
  const WorkspacePage({super.key});

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
      if (!kIsWeb)
        _WorkspaceShortcutItem(
          title: context.l10n.workspaceTabAnnouncementTitle,
          icon: Icons.campaign_outlined,
          onTap: () => context.router.push(AnnouncementFeedRoute()),
          isUpdatesCard: true,
        ),
      _WorkspaceShortcutItem(
        title: context.l10n.workspaceTabPlatformTitle,
        icon: Icons.groups_outlined,
        onTap: () => context.router.push(const PlatformFeedRoute()),
      ),
      if (NativeEngineAvailability.available)
        _WorkspaceShortcutItem(
          title: context.l10n.workspaceTabAiChatTitle,
          icon: Icons.smart_toy_outlined,
          onTap: () => context.router.push(const AiRoute()),
        ),
      _WorkspaceShortcutItem(
        title: context.l10n.workspaceTabManualTitle,
        icon: Icons.menu_book_outlined,
        onTap: kIsWeb
            ? () => unawaited(openWebManualPage(context))
            : () => context.router.push(const ManualBrowserRoute()),
      ),
      _WorkspaceShortcutItem(
        title: context.l10n.workspaceTabReportTitle,
        icon: Icons.feedback_outlined,
        onTap: () => context.router.push(ReportFeedbackRoute()),
      ),
      _WorkspaceShortcutItem(
        title: context.l10n.settingTileAppSettingsTitle,
        icon: Icons.settings_outlined,
        onTap: () => context.router.push(const AppSettingsRoute()),
      ),
    ];

    final unreadCount = kIsWeb ? 0 : ref.watch(unreadAnnouncementCountProvider);

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
              if (it.isUpdatesCard && unreadCount > 0) {
                card = NotificationDot(count: unreadCount, badgeRadius: 13, child: card);
              }
              return card;
            },
          ),
        ),
      ),
    );

    final hasVersionBump = !kIsWeb && ref.watch(pendingVersionBumpProvider);

    return Column(
      children: [
        const DataUpdateBanner(),
        if (hasVersionBump) _buildVersionBumpCard(context, ref),
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
          ref.read(appVersionStateServiceProvider.notifier).acknowledgeVersion(appVersion);
          unawaited(context.router.push(AnnouncementFeedRoute()));
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
                  ref.read(appVersionStateServiceProvider.notifier).acknowledgeVersion(appVersion);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
