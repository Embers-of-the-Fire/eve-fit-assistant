import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/config_list.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/utils/l10n.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class SettingPage extends ConsumerWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ConfigListView(
    children: [
      const ConfigListTile.space(10),
      ConfigListTile.item(
        icon: Icons.backup,
        title: context.l10n.settingTileAppSettingsTitle,
        onTap: () => context.router.push(const AppSettingsRoute()),
      ),
    ],
  );
}
