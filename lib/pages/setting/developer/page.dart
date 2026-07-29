import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/dialog/info_dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/config_list.dart";
import "package:eve_fit_assistant/components/list/dropdown_list_tile.dart";
import "package:eve_fit_assistant/config/force_column.dart";
import "package:eve_fit_assistant/data/proto/release_index.pb.dart";
import "package:eve_fit_assistant/features/app_update/app_update_gate.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_notifier.dart";
import "package:eve_fit_assistant/features/remote_content/cache_manager.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/repo/models/remote_app_release.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import "package:package_info_plus/package_info_plus.dart";

part "attribute_debug_view.dart";
part "debug_log.dart";
part "force_column.dart";
part "remote_content_entry.dart";

@RoutePage()
class DeveloperSettingsPage extends ConsumerWidget {
  const DeveloperSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final developerMode = ref.watch(developerModeProvider);
    if (!developerMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(context.router.replace(const FrontRoute()));
      });
      return const SizedBox.shrink();
    }
    return Layout(
      title: context.l10n.developerSettingsPageTitle,
      child: ConfigListView(
        children: [
          ConfigListTile.title(context.l10n.developerSettingsPageSectionToggles),
          const ConfigListTile.custom(DebugLogTile()),
          const ConfigListTile.custom(AttributeDebugViewTile()),
          const ConfigListTile.custom(RemoteContentSettingsVisibilityTile()),
          const ConfigListTile.custom(ForceColumnTile()),
          ConfigListTile.title(context.l10n.developerSettingsPageSectionActions),
          ConfigListTile.item(
            icon: const Icon(Icons.cloud_sync_outlined),
            title: context.l10n.developerSettingsPageRemoteContentOpenTitle,
            subtitle: context.l10n.developerSettingsPageRemoteContentOpenDescription,
            onTap: () => unawaited(_openRemoteContentSettings(context)),
          ),
          ConfigListTile.item(
            icon: const Icon(Icons.bug_report_outlined),
            title: context.l10n.developerSettingsPageCollectLogsTitle,
            subtitle: context.l10n.developerSettingsPageCollectLogsDescription,
            onTap: () => unawaited(context.router.push(const CollectLogsRoute())),
          ),
          ConfigListTile.item(
            icon: const Icon(Icons.cached_outlined),
            title: context.l10n.developerSettingsPageClearCacheTitle,
            subtitle: context.l10n.developerSettingsPageClearCacheDescription,
            onTap: () => unawaited(_clearCache(context)),
          ),
          ConfigListTile.item(
            icon: const Icon(Icons.update_disabled_outlined),
            title: context.l10n.developerSettingsPageClearUpdateAckTitle,
            subtitle: context.l10n.developerSettingsPageClearUpdateAckDescription,
            onTap: () => unawaited(_clearUpdateAcknowledgment(context, ref)),
          ),
          ConfigListTile.item(
            icon: const Icon(Icons.system_update_alt),
            title: "Preview app update dialog",
            subtitle: "Show the update dialog using the current app version",
            onTap: () => unawaited(_previewUpdateDialog(context)),
          ),
          ConfigListTile.item(
            icon: const Icon(Icons.developer_mode),
            title: "Developer Tools",
            subtitle: "Channel overview, restart init, trigger feedback",
            onTap: () => unawaited(context.router.push(const DeveloperToolsRoute())),
          ),
        ],
      ),
    );
  }
}

Future<void> _previewUpdateDialog(BuildContext context) async {
  final info = await PackageInfo.fromPlatform();
  if (!context.mounted) return;
  final release = RemoteAppRelease(
    releaseId: "dev-preview",
    version: info.version,
    snapshotHash: "",
    index: ReleaseIndex(),
  );
  await showDialog<void>(
    context: context,
    builder: (context) => AppReleaseUpdateDialog(release: release),
  );
}

Future<void> _clearCache(BuildContext context) async {
  final confirmed = await showConfirmDialog(
    context,
    title: context.l10n.developerSettingsPageClearCacheConfirmTitle,
    content: Text(context.l10n.developerSettingsPageClearCacheConfirmDescription),
  );
  if (!confirmed || !context.mounted) return;
  await RemoteCache.clear();
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.developerSettingsPageClearCacheDone)));
}

Future<void> _clearUpdateAcknowledgment(BuildContext context, WidgetRef ref) async {
  ref.read(appVersionStateServiceProvider.notifier).clearReleaseAcknowledgment();
  ref.invalidate(remoteAppReleaseProvider);
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.developerSettingsPageClearUpdateAckDone)));
}

Future<void> _openRemoteContentSettings(BuildContext context) async {
  final confirmed = await showConfirmDialog(
    context,
    title: context.l10n.developerSettingsPageRemoteContentWarningTitle,
    content: Text(context.l10n.developerSettingsPageRemoteContentWarningDescription),
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  await context.router.push(const RemoteContentSettingsRoute());
}
