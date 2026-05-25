import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/card/homepage_link_card.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/bundle/guard.dart";
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <_WorkspaceShortcutItem>[
      _WorkspaceShortcutItem(
        title: context.l10n.workspaceTabActionCreateFitName,
        icon: Icons.add_circle_outline,
        onTap: () async {
          if (!await ensureUsableBundle(context, ref)) {
            return;
          }
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
        title: context.l10n.settingTileBundleManagerTitle,
        icon: Icons.archive_outlined,
        onTap: () => context.router.push(const BundleManagerRoute()),
      ),
      _WorkspaceShortcutItem(
        title: context.l10n.settingTileAppSettingsTitle,
        icon: Icons.settings_outlined,
        onTap: () => context.router.push(const AppSettingsRoute()),
      ),
    ];

    return Center(
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
              final String title = it.title;
              final IconData icon = it.icon;

              return HomepageLinkCard(title: title, icon: icon, onTap: it.onTap);
            },
          ),
        ),
      ),
    );
  }
}
