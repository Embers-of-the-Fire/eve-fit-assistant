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
import "package:eve_fit_assistant/storage/setting/reset_service.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:restart_app/restart_app.dart";

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
          const ConfigListTile.custom(ResetStorageTile()),
        ],
      ),
    );
  }
}

class ResetStorageTile extends ConsumerWidget {
  const ResetStorageTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    leading: const Icon(Icons.delete_forever, color: Colors.red),
    title: const Text("Reset All Storage"),
    subtitle: const Text("Wipe all app data and restart into setup flow"),
    onTap: () => _confirm(context, ref),
  );

  void _confirm(BuildContext context, WidgetRef ref) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text("Reset All Storage?"),
          content: const Text(
            "This will delete all settings, fits, characters, checkouts, cached remote data, and logs. The app will restart and show the welcome/setup flow.",
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text("Cancel")),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                try {
                  await const ResetStorageService().resetAll();
                  await Restart.restartApp();
                } on Exception catch (e, st) {
                  if (context.mounted) {
                    await showDialog<void>(
                      context: context,
                      builder: (errorCtx) => AlertDialog(
                        title: const Text("Reset failed"),
                        content: Text("Could not reset storage: $e"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(errorCtx).pop(),
                            child: const Text("OK"),
                          ),
                        ],
                      ),
                    );
                  }
                  debugPrint("ResetStorageTile failed: $e");
                  debugPrintStack(stackTrace: st);
                }
              },
              child: const Text("Reset & Restart"),
            ),
          ],
        ),
      ),
    );
  }
}
