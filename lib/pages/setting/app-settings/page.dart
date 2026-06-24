import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/dialog/info_dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/config_list.dart";
import "package:eve_fit_assistant/components/list/dropdown_list_tile.dart";
import "package:eve_fit_assistant/config/locale.dart" show Locale;
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/features/feedback/feedback_dialog.dart";
import "package:eve_fit_assistant/features/feedback/feedback_state_store.dart";
import "package:eve_fit_assistant/features/remote_content/etag_cache.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

part "debug_log.dart";
part "developer_mode.dart";
part "developer_remote_content.dart";
part "font_scale.dart";
part "impact_warning.dart";
part "locale.dart";
part "restart_init.dart";
part "select_list.dart";
part "trigger_feedback.dart";

@RoutePage()
class AppSettingsPage extends ConsumerWidget {
  const AppSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Layout(
    title: context.l10n.appSettingsPageTitle,
    child: ConfigListView(
      children: [
        ConfigListTile.title(context.l10n.appSettingsPageSectionGeneral),
        const ConfigListTile.custom(LocaleTile()),
        const ConfigListTile.custom(FontScaleTile()),
        ConfigListTile.title(context.l10n.appSettingsPageSectionSelectList),
        const ConfigListTile.custom(ShipCreateListTile()),
        const ConfigListTile.custom(ListReturnBehaviorTile()),
        ConfigListTile.title(context.l10n.appSettingsPageSectionCheckout),
        const ConfigListTile.custom(CheckoutImpactWarningTile()),
        ConfigListTile.title(context.l10n.appSettingsPageSectionDeveloper),
        const ConfigListTile.custom(DeveloperModeTile()),
        const ConfigListTile.custom(DebugLogTile()),
        const ConfigListTile.custom(RemoteContentSettingsVisibilityTile()),
        ConfigListTile.item(
          icon: const Icon(Icons.cloud_sync_outlined),
          title: context.l10n.appSettingsPageRemoteContentOpenTitle,
          subtitle: context.l10n.appSettingsPageRemoteContentOpenDescription,
          onTap: () => unawaited(_openRemoteContentSettings(context)),
        ),
        ConfigListTile.item(
          icon: const Icon(Icons.bug_report_outlined),
          title: context.l10n.appSettingsPageCollectLogsEntryTitle,
          subtitle: context.l10n.appSettingsPageCollectLogsEntryDescription,
          onTap: () => unawaited(context.router.push(const CollectLogsRoute())),
        ),
        ConfigListTile.item(
          icon: const Icon(Icons.cached_outlined),
          title: context.l10n.appSettingsPageClearCacheTitle,
          subtitle: context.l10n.appSettingsPageClearCacheDescription,
          onTap: () => unawaited(_clearCache(context)),
        ),
        if (ref.watch(developerModeProvider)) const ConfigListTile.custom(RestartInitTile()),
        if (ref.watch(developerModeProvider)) const ConfigListTile.custom(TriggerFeedbackTile()),
      ],
    ),
  );
}

Future<void> _clearCache(BuildContext context) async {
  final confirmed = await showConfirmDialog(
    context,
    title: context.l10n.appSettingsPageClearCacheConfirmTitle,
    content: Text(context.l10n.appSettingsPageClearCacheConfirmDescription),
  );
  if (!confirmed || !context.mounted) return;
  EtagCache.clearAll();
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.appSettingsPageClearCacheDone)));
}
