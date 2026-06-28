import "dart:async";

import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class RestartInitTile extends ConsumerWidget {
  const RestartInitTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    leading: const Icon(Icons.restart_alt),
    title: const Text("Restart Initialization"),
    subtitle: const Text("Reset welcome state and re-run initialization flow"),
    onTap: () => _confirm(context, ref),
  );

  void _confirm(BuildContext context, WidgetRef ref) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text("Restart Initialization?"),
          content: const Text("This will reset the welcome flow and re-run app initialization."),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text("Cancel")),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                ref
                    .read(appSettingServiceProvider.notifier)
                    .update((s) => s.copyWith(welcomeCompleted: false));
              },
              child: const Text("Restart"),
            ),
          ],
        ),
      ),
    );
  }
}
