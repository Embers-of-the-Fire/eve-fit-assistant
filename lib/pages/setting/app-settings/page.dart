import "package:auto_route/annotations.dart";
import "package:eve_fit_assistant/components/config_list.dart";
import "package:eve_fit_assistant/components/dialog.dart";
import "package:eve_fit_assistant/components/dropdown_list_tile.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/config/locale.dart" show Locale;
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

part "debug_log.dart";
part "locale.dart";

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
        ConfigListTile.title(context.l10n.appSettingsPageSectionDeveloper),
        const ConfigListTile.custom(DebugLogTile()),
      ],
    ),
  );
}
