import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/list/config_list.dart";
import "package:eve_fit_assistant/features/documents/repository.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

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
          icon: const Icon(Icons.storage_outlined),
          title: context.l10n.settingTileDataStorageTitle,
          onTap: () => unawaited(context.router.push(const StorageManagement())),
        ),
        ConfigListTile.item(
          icon: const Icon(Icons.feedback_outlined),
          title: context.l10n.workspaceTabReportTitle,
          onTap: () => unawaited(context.router.push(const ReportFeedbackRoute())),
        ),
        ConfigListTile.custom(_buildVersionTile(context, ref)),
      ],
    );
  }

  Widget _buildVersionTile(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadVersionCountProvider);
    return ListTile(
      leading: const Icon(Icons.new_releases_outlined),
      title: Text(context.l10n.settingTileVersionTitle),
      subtitle: Text(context.l10n.settingTileVersionSubtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
              child: Text(
                unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => unawaited(context.router.push(const VersionRoute())),
    );
  }
}
