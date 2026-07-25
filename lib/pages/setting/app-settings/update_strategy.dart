part of "page.dart";

class UpdateIgnoreBugfixTile extends ConsumerWidget {
  const UpdateIgnoreBugfixTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(appSettingServiceProvider).ignoreBugfixUpdates;
    return SwitchListTile(
      secondary: const Icon(Icons.bug_report_outlined),
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: context.l10n.appSettingsPageIgnoreBugfixUpdatesTitle),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: InfoButton(
                title: context.l10n.appSettingsPageIgnoreBugfixUpdatesTitle,
                content: () => Text(context.l10n.appSettingsPageIgnoreBugfixUpdatesDescription),
              ),
            ),
          ],
        ),
      ),
      value: enabled,
      onChanged: (value) {
        ref
            .read(appSettingServiceProvider.notifier)
            .update((setting) => setting.copyWith(ignoreBugfixUpdates: value));
      },
    );
  }
}

class UpdateSilentTile extends ConsumerWidget {
  const UpdateSilentTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(appSettingServiceProvider).silentUpdate;
    return SwitchListTile(
      secondary: const Icon(Icons.download_done_outlined),
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: context.l10n.appSettingsPageSilentUpdateTitle),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: InfoButton(
                title: context.l10n.appSettingsPageSilentUpdateTitle,
                content: () => Text(context.l10n.appSettingsPageSilentUpdateDescription),
              ),
            ),
          ],
        ),
      ),
      value: enabled,
      onChanged: (value) {
        ref
            .read(appSettingServiceProvider.notifier)
            .update((setting) => setting.copyWith(silentUpdate: value));
      },
    );
  }
}
