part of "page.dart";

class LocaleTile extends ConsumerWidget {
  const LocaleTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DropdownListTile(
    icon: Icons.language,
    title: context.l10n.appSettingsPageLocaleTitle,
    subtitle: context.l10n.appSettingsPageLocaleSubtitle,
    initialValue: ref.watch(appSettingServiceProvider).locale,
    onValueChange: (value) =>
        ref.read(appSettingServiceProvider.notifier).update((old) => old.copyWith(locale: value)),
    items: Locale.values
        .map((value) => DropdownMenuItem(value: value, child: Text(value.display)))
        .toList(growable: false),
  );
}
