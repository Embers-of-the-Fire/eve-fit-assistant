import "package:auto_route/annotations.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/dialog/info_dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/config_list.dart";
import "package:eve_fit_assistant/components/list/dropdown_list_tile.dart";
import "package:eve_fit_assistant/config/locale.dart" show Locale;
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

part "debug_log.dart";
part "impact_warning.dart";
part "locale.dart";
part "select_list.dart";

@RoutePage()
class AppSettingsPage extends ConsumerStatefulWidget {
  const AppSettingsPage({super.key});

  @override
  ConsumerState<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends ConsumerState<AppSettingsPage> {
  static const int _remoteContentUnlockTapCount = 5;
  int _developerTapCount = 0;

  @override
  Widget build(BuildContext context) => Layout(
    title: context.l10n.appSettingsPageTitle,
    child: ConfigListView(
      children: [
        ConfigListTile.title(context.l10n.appSettingsPageSectionGeneral),
        const ConfigListTile.custom(LocaleTile()),
        ConfigListTile.title(context.l10n.appSettingsPageSectionSelectList),
        const ConfigListTile.custom(ShipCreateListTile()),
        const ConfigListTile.custom(ListReturnBehaviorTile()),
        ConfigListTile.title(context.l10n.appSettingsPageSectionBundle),
        const ConfigListTile.custom(BundleImpactWarningTile()),
        ConfigListTile.custom(
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _unlockRemoteContentSettings,
            child: ConfigListTile.title(context.l10n.appSettingsPageSectionDeveloper),
          ),
        ),
        const ConfigListTile.custom(DebugLogTile()),
      ],
    ),
  );

  void _unlockRemoteContentSettings() {
    final remoteContent = ref.read(appSettingServiceProvider).remoteContent;
    if (remoteContent.exposed) {
      return;
    }
    _developerTapCount += 1;
    if (_developerTapCount >= _remoteContentUnlockTapCount) {
      ref
          .read(appSettingServiceProvider.notifier)
          .update((setting) => setting.copyWith.remoteContent(exposed: true));
    }
  }
}
