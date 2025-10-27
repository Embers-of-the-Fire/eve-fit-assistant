part of "page.dart";

class ShipCreateListTile extends ConsumerWidget {
  const ShipCreateListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DropdownListTile(
    title: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: context.l10n.appSettingsPageShipSelectTypeTitle),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: InfoButton(
              title: context.l10n.appSettingsPageShipSelectTypeTitle,
              content: () => Text(context.l10n.appSettingsPageShipSelectTypeDescription),
            ),
          ),
        ],
      ),
    ),
    initialValue: ref.watch(
      appSettingServiceProvider.select((t) => t.shipSelectListDisplayVariant),
    ),
    onValueChange: (value) => ref
        .read(appSettingServiceProvider.notifier)
        .update((old) => old.copyWith(shipSelectListDisplayVariant: value)),
    items: [
      DropdownMenuItem(
        value: TypeListDisplayVariant.category,
        child: Text(context.l10n.useCategorySelectList),
      ),
      DropdownMenuItem(
        value: TypeListDisplayVariant.marketGroup,
        child: Text(context.l10n.useMarketGroupSelectList),
      ),
    ],
  );
}
