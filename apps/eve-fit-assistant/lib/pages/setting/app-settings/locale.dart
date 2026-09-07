part of "page.dart";

class LocaleTile extends ConsumerWidget {
  const LocaleTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appSettingServiceProvider).locale;

    // §5.3 persistent indicator: while the active locale's localization
    // database is not available, say so on the tile. Informational only — the
    // app remains fully usable with placeholder names.
    final availability = ref.watch(localizationDbAvailabilityProvider(locale.name)).value;
    final missing = availability != null && availability is! LocalizationDbAvailable;

    return DropdownListTile(
      icon: Icons.language,
      title: Text(context.l10n.appSettingsPageLocaleTitle),
      subtitle: missing
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.appSettingsPageLocaleSubtitle),
                Text(
                  context.l10n.localeDbMissingIndicator,
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.error,
                  ),
                ),
              ],
            )
          : Text(context.l10n.appSettingsPageLocaleSubtitle),
      initialValue: locale,
      onValueChange: (value) {
        ref.read(appSettingServiceProvider.notifier).update((old) => old.copyWith(locale: value));
        // Evaluated after the choice is persisted; cancel leaves the locale
        // switched with placeholders rendering.
        unawaited(offerLocaleLocalizationDb(context, ref, value));
      },
      items: Locale.values
          .map((value) => DropdownMenuItem(value: value, child: Text(value.display)))
          .toList(growable: false),
    );
  }
}
