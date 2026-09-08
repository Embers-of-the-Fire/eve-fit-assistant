import "dart:async";

import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/features/locale_switch/locale_switch_dialog.dart";
import "package:eve_fit_assistant/storage/repo/localization_db.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/material.dart" hide Locale;
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";

import "../../test_helpers.dart";

class _TestAppSettingService extends AppSettingService {
  _TestAppSettingService(this._initial);

  final AppSetting _initial;

  @override
  AppSetting build() => _initial;

  @override
  void update(AppSetting Function(AppSetting) updater) => state = updater(state);
}

/// Mimics LocaleTile/LanguageStepPage: persists the choice, then starts
/// the locale-switch flow without awaiting it.
class _Harness extends ConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Column(
      children: [
        for (final locale in Locale.values)
          TextButton(
            onPressed: () {
              ref
                  .read(appSettingServiceProvider.notifier)
                  .update((old) => old.copyWith(locale: locale));
              unawaited(offerLocaleLocalizationDb(context, ref, locale));
            },
            child: Text("pick ${locale.name}"),
          ),
      ],
    ),
  );
}

void main() {
  AppSetting testAppSetting(Locale locale) => AppSetting(
    locale: locale,
    enableDebugLog: false,
    shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
    showCheckoutImpactWarnings: true,
    typeListReturnBehavior: TypeListReturnBehavior.previousPage,
    developerMode: false,
  );

  testWidgets("discards the availability result of an obsolete locale", (tester) async {
    final enAvailability = Completer<LocalizationDbAvailability>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingServiceProvider.overrideWith(
            () => _TestAppSettingService(testAppSetting(Locale.zh)),
          ),
          activeCheckoutIdProvider.overrideWith((_) => const Some("c1")),
          localizationDbAvailabilityProvider("en").overrideWith((_) => enAvailability.future),
          localizationDbAvailabilityProvider(
            "zh",
          ).overrideWith((_) async => const LocalizationDbDownloadable(sizeBytes: 2048)),
        ],
        child: testApp(const _Harness()),
      ),
    );

    // Pick en: its availability result is delayed.
    await tester.tap(find.text("pick en"));
    await tester.pump();

    // Pick zh before the en result arrives: zh is now the active locale and
    // its availability resolves immediately.
    await tester.tap(find.text("pick zh"));
    await tester.pumpAndSettle();

    // Only the current locale (zh) opens a dialog.
    expect(find.byType(ConfirmDialog), findsOneWidget);
    expect(find.textContaining("简体中文"), findsWidgets);
    expect(find.textContaining("English"), findsNothing);

    // The delayed en result completes later; it is obsolete and must not
    // open a second dialog.
    enAvailability.complete(const LocalizationDbDownloadable(sizeBytes: 1024));
    await tester.pumpAndSettle();

    expect(find.byType(ConfirmDialog), findsOneWidget);
    expect(find.textContaining("English"), findsNothing);
  });
}
