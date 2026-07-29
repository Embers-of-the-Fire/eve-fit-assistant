part of "page.dart";

class ListTileAntiScrollTile extends ConsumerWidget {
  const ListTileAntiScrollTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DropdownListTile(
    title: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: context.l10n.appSettingsPageAntiScrollTitle),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: InfoButton(
              title: context.l10n.appSettingsPageAntiScrollTitle,
              content: () => Text(context.l10n.appSettingsPageAntiScrollDescription),
            ),
          ),
        ],
      ),
    ),
    initialValue: ref.watch(appSettingServiceProvider.select((t) => t.listTileAntiScrollLevel)),
    onValueChange: (value) => ref
        .read(appSettingServiceProvider.notifier)
        .update((old) => old.copyWith(listTileAntiScrollLevel: value)),
    items: [
      DropdownMenuItem(
        value: ListTileAntiScrollLevel.closed,
        child: Text(context.l10n.appSettingsPageAntiScrollClosed),
      ),
      DropdownMenuItem(
        value: ListTileAntiScrollLevel.weak,
        child: Text(context.l10n.appSettingsPageAntiScrollWeak),
      ),
      DropdownMenuItem(
        value: ListTileAntiScrollLevel.medium,
        child: Text(context.l10n.appSettingsPageAntiScrollMedium),
      ),
      DropdownMenuItem(
        value: ListTileAntiScrollLevel.strong,
        child: Text(context.l10n.appSettingsPageAntiScrollStrong),
      ),
    ],
  );
}
