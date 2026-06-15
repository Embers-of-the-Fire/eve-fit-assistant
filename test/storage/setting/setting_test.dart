import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter_test/flutter_test.dart";
import "package:riverpod/riverpod.dart";

void main() {
  AppSetting testAppSetting(Locale locale) => AppSetting(
    locale: locale,
    enableDebugLog: false,
    shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
    showCheckoutImpactWarnings: true,
    typeListReturnBehavior: TypeListReturnBehavior.previousPage,
  );

  test("localeProvider returns locale from overridden AppSettingService", () {
    final container = ProviderContainer(
      overrides: [appSettingServiceProvider.overrideWithValue(testAppSetting(Locale.zh))],
    );
    addTearDown(container.dispose);

    expect(container.read(localeProvider), Locale.zh);
  });

  test("fontScaleProvider returns default font scale from overridden AppSettingService", () {
    final container = ProviderContainer(
      overrides: [appSettingServiceProvider.overrideWithValue(testAppSetting(Locale.en))],
    );
    addTearDown(container.dispose);

    expect(container.read(fontScaleProvider), 1.0);
  });

  test("localeProvider falls back to en when appSetting is set to en", () {
    final container = ProviderContainer(
      overrides: [appSettingServiceProvider.overrideWithValue(testAppSetting(Locale.en))],
    );
    addTearDown(container.dispose);

    expect(container.read(localeProvider), Locale.en);
  });
}
