import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/card/homepage_link_card.dart";
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Example items to demonstrate localization and different iconography
    final items = <_WorkspaceShortcutItem>[
      _WorkspaceShortcutItem(
        title: context.l10n.workspaceTabActionCreateFitName,
        icon: Icons.add_circle_outline,
        onTap: () => context.router.push(const FitCreationRoute()),
      ),
      _WorkspaceShortcutItem(title: "设置", icon: Icons.settings, onTap: () {}),
      _WorkspaceShortcutItem(title: "Workspace", icon: Icons.workspaces, onTap: () {}),
      _WorkspaceShortcutItem(title: "工作区", icon: Icons.workspace_premium, onTap: () {}),
      _WorkspaceShortcutItem(title: "Files", icon: Icons.folder, onTap: () {}),
      _WorkspaceShortcutItem(title: "文件", icon: Icons.folder_open, onTap: () {}),
      _WorkspaceShortcutItem(title: "Analytics", icon: Icons.show_chart, onTap: () {}),
      _WorkspaceShortcutItem(title: "分析", icon: Icons.bar_chart, onTap: () {}),
      _WorkspaceShortcutItem(title: "Tools", icon: Icons.build, onTap: () {}),
      _WorkspaceShortcutItem(title: "工具", icon: Icons.construction, onTap: () {}),
    ];

    return Padding(
      padding: const .all(12),
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
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
    );
  }
}
