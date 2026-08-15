import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/dialog/info_dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/config_list.dart";
import "package:eve_fit_assistant/components/list/dropdown_list_tile.dart";
import "package:eve_fit_assistant/config/list_tile_anti_scroll.dart";
import "package:eve_fit_assistant/config/loading.dart";
import "package:eve_fit_assistant/config/locale.dart" show Locale;
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/storage_root.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/features/app_update/platform/update_platform.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:file_picker/file_picker.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:path/path.dart" as p;
import "package:restart_app/restart_app.dart";

part "anti_scroll.dart";
part "font_scale.dart";
part "impact_warning.dart";
part "locale.dart";
part "market_price.dart";
part "select_list.dart";
part "storage_root.dart";
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
        const ConfigListTile.custom(ListTileAntiScrollTile()),
        // The configured storage root is honored on every native platform,
        // but only Windows exposes editing.
        if (storageRootEditable) ...[
          ConfigListTile.title(context.l10n.appSettingsPageSectionStorage),
          const ConfigListTile.custom(StorageRootTile()),
        ],
        ConfigListTile.title(context.l10n.appSettingsPageSectionSelectList),
        const ConfigListTile.custom(ShipCreateListTile()),
        const ConfigListTile.custom(ListReturnBehaviorTile()),
        ConfigListTile.title(context.l10n.appSettingsPageSectionCheckout),
        const ConfigListTile.custom(CheckoutImpactWarningTile()),
        // Market price is disabled at the provider root on web, so its
        // settings do not apply there.
        if (!kIsWeb) ...[
          ConfigListTile.title(context.l10n.appSettingsPageSectionMarket),
          const ConfigListTile.custom(MarketServerFallbackTile()),
        ],
        // App update detection is not served on web, so its settings do not
        // apply there.
        if (!kIsWeb) ...[
          ConfigListTile.title(context.l10n.appSettingsPageSectionUpdate),
          const ConfigListTile.custom(UpdateIgnoreBugfixTile()),
          if (ref.watch(appUpdatePlatformAdapterProvider).supportsSelfUpdate)
            const ConfigListTile.custom(UpdateSilentTile()),
        ],
      ],
    ),
  );
}
