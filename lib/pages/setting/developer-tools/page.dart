// THIS FILE DOES NOT USE LOCALIZATION.
// All strings are hardcoded English — this is a developer-facing page,
// not an end-user screen.

import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/config_list.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/pages/setting/app-settings/restart_init.dart";
import "package:eve_fit_assistant/pages/setting/app-settings/trigger_feedback.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

@RoutePage()
class DeveloperToolsPage extends ConsumerWidget {
  const DeveloperToolsPage({super.key});

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
      title: "Developer Tools",
      child: ConfigListView(
        children: [
          const ConfigListTile.space(20),
          ConfigListTile.item(
            icon: const Icon(Icons.info_outline),
            title: "Channel Overview",
            subtitle: "Remote channel metadata and sync status",
            onTap: () => unawaited(context.router.push(const ChannelOverviewRoute())),
          ),
          const ConfigListTile.custom(RestartInitTile()),
          const ConfigListTile.custom(TriggerFeedbackTile()),
        ],
      ),
    );
  }
}
