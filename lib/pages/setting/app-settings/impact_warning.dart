part of "page.dart";

class BundleImpactWarningTile extends ConsumerWidget {
  const BundleImpactWarningTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(appSettingServiceProvider).showBundleImpactWarnings;
    return SwitchListTile(
      secondary: const Icon(Icons.warning_amber_outlined),
      title: Text(context.l10n.appSettingsPageBundleImpactWarningTitle),
      subtitle: Text(context.l10n.appSettingsPageBundleImpactWarningDescription),
      value: enabled,
      onChanged: (value) async {
        if (!value) {
          final confirmed = await showConfirmDialog(
            context,
            title: context.l10n.bundleImpactDisableConfirmTitle,
            content: Text(context.l10n.bundleImpactDisableConfirmDescription),
          );
          if (!confirmed || !context.mounted) {
            return;
          }
        }

        ref
            .read(appSettingServiceProvider.notifier)
            .update((setting) => setting.copyWith(showBundleImpactWarnings: value));
      },
    );
  }
}
