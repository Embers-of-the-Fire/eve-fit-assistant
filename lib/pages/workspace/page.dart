import "package:eve_fit_assistant/components/card.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class WorkspacePage extends ConsumerWidget {
  const WorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Example items to demonstrate localization and different iconography
    final items = <Map<String, dynamic>>[
      {"title": "Settings", "icon": Icons.settings},
      {"title": "设置", "icon": Icons.settings},
      {"title": "Workspace", "icon": Icons.workspaces},
      {"title": "工作区", "icon": Icons.workspace_premium},
      {"title": "Files", "icon": Icons.folder},
      {"title": "文件", "icon": Icons.folder_open},
      {"title": "Analytics", "icon": Icons.show_chart},
      {"title": "分析", "icon": Icons.bar_chart},
      {"title": "Tools", "icon": Icons.build},
      {"title": "工具", "icon": Icons.construction},
    ];

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1, // ensure square tiles
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final it = items[index];
          // Cast values to concrete types so static analysis is satisfied
          final String title = it["title"] as String;
          final IconData icon = it["icon"] as IconData;

          return HomepageLinkCard(
            title: title,
            icon: icon,
            onTap: () {
              // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tapped: $title')));
            },
          );
        },
      ),
    );
  }
}
