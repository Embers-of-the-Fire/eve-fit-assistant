@TestOn("vm")
library;

import "package:eve_fit_assistant/config/locale.dart" as app_locale;
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/features/remote_content/cadence.dart";
import "package:eve_fit_assistant/features/remote_content/channel_switch.dart";
import "package:eve_fit_assistant/features/remote_content/channel_switch_dialog.dart";
import "package:eve_fit_assistant/pages/setting/app-settings/page.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

class _TestAppSettingService extends AppSettingService {
  _TestAppSettingService(this._initial);

  final AppSetting _initial;

  @override
  AppSetting build() => _initial;

  @override
  void update(AppSetting Function(AppSetting) updater) => state = updater(state);
}

AppSetting _setting({String channel = "stable", String cadence = "weekly"}) => AppSetting(
  locale: app_locale.Locale.en,
  enableDebugLog: false,
  shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
  showCheckoutImpactWarnings: true,
  typeListReturnBehavior: TypeListReturnBehavior.previousPage,
  developerMode: false,
  remoteContent: RemoteContentSetting(channel: channel, cadence: cadence),
);

Widget _wrap(Widget tile, {String channel = "stable", String? switchError, List<String>? calls}) =>
    ProviderScope(
      overrides: [
        appSettingServiceProvider.overrideWith(
          () => _TestAppSettingService(_setting(channel: channel)),
        ),
        channelSwitchActionProvider.overrideWithValue((target) async {
          calls?.add(target);
          return switchError;
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale("en"),
        home: Scaffold(body: tile),
      ),
    );

Future<void> _selectDropdownItem<T>(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButton<T>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("tapping the tile opens the channel switch dialog", (tester) async {
    await tester.pumpWidget(_wrap(const DataChannelTile()));

    await tester.tap(find.byType(DataChannelTile));
    await tester.pumpAndSettle();

    expect(find.byType(ChannelSwitchDialog), findsOneWidget);
  });

  testWidgets("the tile shows the current channel", (tester) async {
    await tester.pumpWidget(_wrap(const DataChannelTile(), channel: "testing"));

    expect(find.text("Testing"), findsOneWidget);
  });

  testWidgets("cadence dropdown is disabled on the testing channel", (tester) async {
    await tester.pumpWidget(_wrap(const DataCadenceTile(), channel: "testing"));

    final dropdown = tester.widget<DropdownButton<DataCadence>>(
      find.byType(DropdownButton<DataCadence>),
    );
    expect(dropdown.onChanged, isNull);
    expect(
      find.text("The testing channel always tracks the latest data immediately."),
      findsOneWidget,
    );
  });

  testWidgets("cadence change commits immediately on the stable channel", (tester) async {
    await tester.pumpWidget(_wrap(const DataCadenceTile()));

    await _selectDropdownItem<DataCadence>(tester, "Monthly");

    final context = tester.element(find.byType(DataCadenceTile));
    final container = ProviderScope.containerOf(context);
    expect(container.read(appSettingServiceProvider).remoteContent.cadence, "monthly");
  });
}
