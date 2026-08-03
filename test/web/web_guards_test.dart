@TestOn("browser")
library;

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/data/proto/release_index.pb.dart";
import "package:eve_fit_assistant/features/app_update/platform/update_platform.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";
import "package:eve_fit_assistant/features/schema_guard/migration_gate.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("app update on web", () {
    test("detectAppUpdatePlatform falls back to the unsupported adapter", () {
      final adapter = detectAppUpdatePlatform();

      expect(adapter, isA<UnsupportedAppUpdateAdapter>());
      expect(adapter.supportsSelfUpdate, isFalse);
      expect(adapter.hasArtifacts(ReleaseIndex()), isFalse);
      expect(adapter.downloadTargets(ReleaseIndex()), isEmpty);
    });
  });

  group("dio factory on web", () {
    test("createBlobDio builds without an IO adapter", () {
      final dio = createBlobDio();
      addTearDown(dio.close);

      expect(dio.options.headers["User-Agent"], contains("EFA/"));
      expect(dio.options.headers["Accept-Encoding"], contains("gzip"));
    });
  });

  group("logger on web", () {
    test("console-only logging does not throw", () {
      GlobalLogger.init("/ignored", enableDebugLog: true);

      expect(() => debug("d"), returnsNormally);
      expect(() => info("i"), returnsNormally);
      expect(() => warning("w"), returnsNormally);
      expect(() => error("e"), returnsNormally);
      expect(() => fatal("f"), returnsNormally);
    });
  });

  group("MigrationGate on web", () {
    testWidgets("skips legacy detection and completes immediately", (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MigrationGate(onMigrationComplete: () => completed = true, theme: ThemeData()),
      );
      await tester.pump();

      expect(completed, isTrue);
    });
  });
}
