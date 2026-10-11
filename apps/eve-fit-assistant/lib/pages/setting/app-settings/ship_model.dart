part of "page.dart";

class ShipModelVariantTile extends ConsumerWidget {
  const ShipModelVariantTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DropdownListTile(
    title: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: context.l10n.appSettingsPageShipModelTitle),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: InfoButton(
              title: context.l10n.appSettingsPageShipModelTitle,
              content: () => Text(context.l10n.appSettingsPageShipModelDescription),
            ),
          ),
        ],
      ),
    ),
    initialValue: ref.watch(appSettingServiceProvider.select((t) => t.shipModelVariant)),
    onValueChange: (value) => ref
        .read(appSettingServiceProvider.notifier)
        .update((old) => old.copyWith(shipModelVariant: value)),
    items: [
      DropdownMenuItem(
        value: ShipModelVariant.textured,
        child: Text(context.l10n.shipModelVariantTextured),
      ),
      DropdownMenuItem(
        value: ShipModelVariant.geometryOnly,
        child: Text(context.l10n.shipModelVariantGeometryOnly),
      ),
    ],
  );
}
