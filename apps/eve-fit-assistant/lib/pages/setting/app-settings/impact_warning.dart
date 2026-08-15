part of "page.dart";

class CheckoutImpactWarningTile extends ConsumerWidget {
  const CheckoutImpactWarningTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(appSettingServiceProvider).showCheckoutImpactWarnings;
    return SwitchListTile(
      secondary: const Icon(Icons.warning_amber_outlined),
      title: Text(context.l10n.appSettingsPageCheckoutImpactWarningTitle),
      subtitle: Text(context.l10n.appSettingsPageCheckoutImpactWarningDescription),
      value: enabled,
      onChanged: (value) async {
        if (!value) {
          final confirmed = await showConfirmDialog(
            context,
            title: context.l10n.checkoutImpactDisableConfirmTitle,
            content: Text(context.l10n.checkoutImpactDisableConfirmDescription),
          );
          if (!confirmed || !context.mounted) {
            return;
          }
        }

        ref
            .read(appSettingServiceProvider.notifier)
            .update((setting) => setting.copyWith(showCheckoutImpactWarnings: value));
      },
    );
  }
}
