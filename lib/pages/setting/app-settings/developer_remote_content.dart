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
      title: Text(context.l10n.appSettingsPageRemoteContentVisibleTitle),
      subtitle: Text(context.l10n.appSettingsPageRemoteContentVisibleDescription),
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
    title: context.l10n.appSettingsPageRemoteContentWarningTitle,
    content: Text(context.l10n.appSettingsPageRemoteContentWarningDescription),
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  await context.router.push(const RemoteContentSettingsRoute());
}
