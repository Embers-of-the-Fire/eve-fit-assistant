part of "page.dart";

class MarketServerFallbackTile extends ConsumerWidget {
  const MarketServerFallbackTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DropdownListTile<String>(
    icon: Icons.paid_outlined,
    title: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: context.l10n.appSettingsPageMarketServerFallbackTitle),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: InfoButton(
              title: context.l10n.appSettingsPageMarketServerFallbackTitle,
              content: () => Text(context.l10n.appSettingsPageMarketServerFallbackDescription),
            ),
          ),
        ],
      ),
    ),
    initialValue: ref.watch(appSettingServiceProvider.select((t) => t.marketServerFallback)),
    onValueChange: (value) => ref
        .read(appSettingServiceProvider.notifier)
        .update((old) => old.copyWith(marketServerFallback: value)),
    items: [
      DropdownMenuItem(value: "", child: Text(context.l10n.marketServerFallbackDefault)),
      DropdownMenuItem(value: "serenity", child: Text(context.l10n.marketServerSerenity)),
      DropdownMenuItem(value: "tranquility", child: Text(context.l10n.marketServerTranquility)),
    ],
  );
}
