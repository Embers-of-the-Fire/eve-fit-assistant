import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets("ProviderScope with overridden appSetting renders without crash", (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingServiceProvider.overrideWithValue(
            AppSetting(
              locale: Locale.en,
              enableDebugLog: false,
              shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
              showBundleImpactWarnings: true,
              typeListReturnBehavior: TypeListReturnBehavior.previousPage,
            ),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final fontScale = ref.watch(fontScaleProvider);
            return MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData().copyWith(textScaler: TextScaler.linear(fontScale)),
                child: const Scaffold(body: Center(child: Text("Smoke Test"))),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text("Smoke Test"), findsOneWidget);
  });
}
