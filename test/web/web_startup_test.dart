@TestOn("browser")
library;

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("PathProvider on web", () {
    test("init uses placeholder paths without path_provider", () async {
      await PathProvider.init();

      expect(PathProvider.documentsPath, "/");
      expect(PathProvider.tempPath, "/");
      expect(PathProvider.appSupportPath, "/");
      expect(PathProvider.cachesPath, "/");
      expect(PathProvider.downloadsPath, isNull);
    });

    test("derived paths resolve under the placeholder root", () async {
      await PathProvider.init();

      expect(PathProvider.settingsPath, "/settings");
      expect(PathProvider.logsPath, "/logs");
      expect(PathProvider.runtimePath, "/runtime/v2");
    });
  });

  group("AppSettingService on web", () {
    test("init loads defaults from the settings store", () async {
      await AppSettingService.init();

      expect(AppSettingService.appSetting.welcomeCompleted, isFalse);
      expect(AppSettingService.appSetting.developerMode, isFalse);
      expect(AppSettingService.appSetting.fontScale, 1.0);
    });

    test("updates apply in memory and persist to the settings store", () async {
      await AppSettingService.init();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container
            .read(appSettingServiceProvider.notifier)
            .update((s) => s.copyWith(welcomeCompleted: true, fontScale: 1.5)),
        returnsNormally,
      );
      expect(container.read(appSettingServiceProvider).welcomeCompleted, isTrue);
      expect(container.read(appSettingServiceProvider).fontScale, 1.5);
    });
  });
}
