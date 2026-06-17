part of "page.dart";

class DeveloperModeTile extends ConsumerWidget {
  const DeveloperModeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(appSettingServiceProvider.select((s) => s.developerMode));
    return SwitchListTile(
      secondary: const Icon(Icons.developer_mode),
      title: Text(context.l10n.appSettingsPageDeveloperModeTitle),
      subtitle: Text(context.l10n.appSettingsPageDeveloperModeDescription),
      value: enabled,
      onChanged: (value) async {
        if (value) {
          final confirmed = await showConfirmDialog(
            context,
            title: context.l10n.developerModeEnableConfirmTitle,
            content: Text(context.l10n.developerModeEnableConfirmDescription),
          );
          if (!confirmed || !context.mounted) return;
        }
        ref
            .read(appSettingServiceProvider.notifier)
            .update((s) => s.copyWith(developerMode: value));
      },
    );
  }
}
