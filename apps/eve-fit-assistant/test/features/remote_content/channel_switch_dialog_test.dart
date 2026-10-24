@TestOn("vm")
library;

import "dart:async";

import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/config/locale.dart" as app_locale;
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
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

AppSetting _setting({String channel = "stable"}) => AppSetting(
  locale: app_locale.Locale.en,
  enableDebugLog: false,
  shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
  showCheckoutImpactWarnings: true,
  typeListReturnBehavior: TypeListReturnBehavior.previousPage,
  developerMode: false,
  remoteContent: RemoteContentSetting(channel: channel),
);

Widget _wrap({String channel = "stable", String? switchError, List<String>? calls}) =>
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
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => unawaited(showChannelSwitchDialog(context)),
              child: const Text("open"),
            ),
          ),
        ),
      ),
    );

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.text("open"));
  await tester.pumpAndSettle();
  expect(find.byType(ChannelSwitchDialog), findsOneWidget);
}

void main() {
  testWidgets("stable to testing asks for the warning before switching", (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_wrap(calls: calls));
    await _openDialog(tester);

    await tester.tap(find.text("Testing"));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, "Switch"));
    await tester.pumpAndSettle();

    expect(find.text("Switch to Testing?"), findsOneWidget);
    expect(calls, isEmpty);

    await tester.tap(find.widgetWithText(ElevatedButton, "Confirm"));
    await tester.pumpAndSettle();

    expect(calls, ["testing"]);
    expect(find.byType(ChannelSwitchDialog), findsNothing);
  });

  testWidgets("canceling the testing warning does not switch", (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_wrap(calls: calls));
    await _openDialog(tester);

    await tester.tap(find.text("Testing"));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, "Switch"));
    await tester.pumpAndSettle();

    expect(find.text("Switch to Testing?"), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(ConfirmDialog),
        matching: find.widgetWithText(TextButton, "Cancel"),
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, isEmpty);
    expect(find.byType(ChannelSwitchDialog), findsOneWidget);
  });

  testWidgets("testing to stable switches without the warning", (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_wrap(channel: "testing", calls: calls));
    await _openDialog(tester);

    await tester.tap(find.text("Stable"));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, "Switch"));
    await tester.pumpAndSettle();

    expect(find.text("Switch to Testing?"), findsNothing);
    expect(calls, ["stable"]);
    expect(find.byType(ChannelSwitchDialog), findsNothing);
  });

  testWidgets("failed switch keeps the dialog open and shows the error", (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_wrap(channel: "testing", switchError: "sync failed", calls: calls));
    await _openDialog(tester);

    await tester.tap(find.text("Stable"));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, "Switch"));
    await tester.pumpAndSettle();

    expect(calls, ["stable"]);
    expect(find.byType(ChannelSwitchDialog), findsOneWidget);
    expect(find.textContaining("sync failed"), findsOneWidget);
  });

  testWidgets("switch stays disabled while the current channel is selected", (tester) async {
    await tester.pumpWidget(_wrap());
    await _openDialog(tester);

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, "Switch"),
    );
    expect(button.onPressed, isNull);
  });
}
