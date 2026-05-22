import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/list/config_list.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

class SettingPage extends ConsumerWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showRemoteContent = ref.watch(
      appSettingServiceProvider.select((setting) => setting.remoteContent.exposed),
    );
    return ConfigListView(
      children: [
        const ConfigListTile.space(20),
        ConfigListTile.item(
          icon: const Icon(Icons.settings),
          title: context.l10n.settingTileAppSettingsTitle,
          onTap: () => unawaited(context.router.push(const AppSettingsRoute())),
        ),
        if (showRemoteContent)
          ConfigListTile.item(
            icon: const Icon(Icons.cloud_sync_outlined),
            title: context.l10n.settingTileRemoteContentTitle,
            onTap: () => unawaited(context.router.push(const RemoteContentSettingsRoute())),
          ),
        ConfigListTile.item(
          icon: const FaIcon(FontAwesomeIcons.box),
          title: context.l10n.settingTileBundleManagerTitle,
          onTap: () => unawaited(context.router.push(const BundleManagerRoute())),
        ),
        ConfigListTile.item(
          icon: const Icon(Icons.new_releases_outlined),
          title: context.l10n.settingTileVersionTitle,
          subtitle: context.l10n.settingTileVersionSubtitle,
          onTap: () => unawaited(context.router.push(const VersionRoute())),
        ),
      ],
    );
  }
}
