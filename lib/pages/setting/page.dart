import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/config_list.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

class SettingPage extends ConsumerWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ConfigListView(
    children: [
      const ConfigListTile.space(20),
      ConfigListTile.item(
        icon: Icons.settings,
        title: context.l10n.settingTileAppSettingsTitle,
        onTap: () => context.router.push(const AppSettingsRoute()),
      ),
      ConfigListTile.item(
        icon: FontAwesomeIcons.box,
        title: context.l10n.settingTileBundleManagerTitle,
        onTap: () => context.router.push(const BundleManagerRoute()),
      ),
    ],
  );
}
