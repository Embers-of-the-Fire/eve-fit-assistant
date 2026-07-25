import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/dialog/info_dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/config_list.dart";
import "package:eve_fit_assistant/components/list/dropdown_list_tile.dart";
import "package:eve_fit_assistant/config/locale.dart" show Locale;
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

part "font_scale.dart";
part "impact_warning.dart";
part "locale.dart";
part "market_price.dart";
part "select_list.dart";
part "update_strategy.dart";

@RoutePage()
class AppSettingsPage extends ConsumerWidget {
  const AppSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Layout(
    title: context.l10n.appSettingsPageTitle,
    child: ConfigListView(
      children: [
        ConfigListTile.title(context.l10n.appSettingsPageSectionGeneral),
        const ConfigListTile.custom(LocaleTile()),
        const ConfigListTile.custom(FontScaleTile()),
        ConfigListTile.title(context.l10n.appSettingsPageSectionSelectList),
        const ConfigListTile.custom(ShipCreateListTile()),
        const ConfigListTile.custom(ListReturnBehaviorTile()),
        ConfigListTile.title(context.l10n.appSettingsPageSectionCheckout),
        const ConfigListTile.custom(CheckoutImpactWarningTile()),
        ConfigListTile.title(context.l10n.appSettingsPageSectionMarket),
        const ConfigListTile.custom(MarketServerFallbackTile()),
        ConfigListTile.title(context.l10n.appSettingsPageSectionUpdate),
        const ConfigListTile.custom(UpdateIgnoreBugfixTile()),
        const ConfigListTile.custom(UpdateSilentTile()),
      ],
    ),
  );
}
