part of "page.dart";

class RemoteContentSettingsVisibilityTile extends ConsumerWidget {
  const RemoteContentSettingsVisibilityTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exposed = ref.watch(
      appSettingServiceProvider.select((setting) => setting.remoteContent.exposed),
    );
    return SwitchListTile(
      secondary: const Icon(Icons.visibility_outlined),
      title: const Text("Show Remote Content Settings"),
      subtitle: const Text("Show or hide the Remote Content entry on the Settings page."),
      value: exposed,
      onChanged: (value) => ref
          .read(appSettingServiceProvider.notifier)
          .update((setting) => setting.copyWith.remoteContent(exposed: value)),
    );
  }
}

Future<void> _openRemoteContentSettings(BuildContext context) async {
  final confirmed = await showConfirmDialog(
    context,
    title: "Open remote content settings?",
    content: const Text(
      "Remote content settings are experimental and can affect future document, release, and bundle metadata discovery. Continue only if you know what endpoint to use.",
    ),
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  await context.router.push(const RemoteContentSettingsRoute());
}
