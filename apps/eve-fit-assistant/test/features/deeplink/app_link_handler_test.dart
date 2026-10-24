@TestOn("vm")
library;

import "dart:async";
import "dart:io";

import "package:eve_fit_assistant/config/locale.dart" as app_locale;
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/features/deeplink/app_link_handler.dart";
import "package:eve_fit_assistant/features/remote_content/channel_switch.dart";
import "package:eve_fit_assistant/features/remote_content/channel_switch_dialog.dart";
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

AppSetting _setting() => AppSetting(
  locale: app_locale.Locale.en,
  enableDebugLog: false,
  shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
  showCheckoutImpactWarnings: true,
  typeListReturnBehavior: TypeListReturnBehavior.previousPage,
  developerMode: false,
  remoteContent: const RemoteContentSetting(channel: "stable"),
);

Widget _wrap(String link) => ProviderScope(
  overrides: [
    appSettingServiceProvider.overrideWith(() => _TestAppSettingService(_setting())),
    channelSwitchActionProvider.overrideWithValue((_) async => null),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale("en"),
    home: Builder(
      builder: (context) => Scaffold(
        body: Consumer(
          builder: (context, ref, _) => ElevatedButton(
            onPressed: () =>
                unawaited(ref.read(appLinkHandlerProvider).open(context, link)),
            child: const Text("open"),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_app_link_handler_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  testWidgets("the switch-channel action opens the channel switch dialog", (tester) async {
    await tester.pumpWidget(_wrap("efa://action/switch-channel"));

    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();

    expect(find.byType(ChannelSwitchDialog), findsOneWidget);
  });

  testWidgets("an unknown action reports an invalid link", (tester) async {
    await tester.pumpWidget(_wrap("efa://action/bogus"));

    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();

    expect(find.byType(ChannelSwitchDialog), findsNothing);
    expect(find.text("Invalid link"), findsOneWidget);
  });
}
