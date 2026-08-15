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
