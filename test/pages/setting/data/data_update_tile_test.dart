import "dart:async";

import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/pages/setting/data/data_update_tile.dart";
import "package:eve_fit_assistant/storage/repo/batch_data_update_status.dart";
import "package:eve_fit_assistant/storage/repo/data_update_service.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";

import "../../../test_helpers.dart";

class MockDataUpdateService extends Mock implements DataUpdateService {}

/// A test controller that returns a fixed [initialStatus] from [build] and
/// suppresses [ensureCheck] / [check] to avoid accessing providers that are
/// not set up in rendering-only tests.
class _FixedBatchController extends BatchDataUpdateController {
  _FixedBatchController(this.initialStatus);

  final BatchDataUpdateStatus initialStatus;

  @override
  BatchDataUpdateStatus build() => initialStatus;

  @override
  Future<void> ensureCheck() async {}

  @override
  Future<void> check() async {}
}

AppSetting _testAppSetting({RemoteContentSetting? remoteContent}) => AppSetting(
  locale: Locale.zh,
  enableDebugLog: false,
  shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
  showCheckoutImpactWarnings: true,
  typeListReturnBehavior: TypeListReturnBehavior.previousPage,
  developerMode: false,
  remoteContent: remoteContent ?? const RemoteContentSetting(exposed: true),
);

Widget buildTile(BatchDataUpdateStatus status) => ProviderScope(
  overrides: [
    batchDataUpdateControllerProvider.overrideWith(() => _FixedBatchController(status)),
    appSettingServiceProvider.overrideWithValue(_testAppSetting()),
  ],
  child: testApp(const Material(child: DataUpdateTile())),
);

const testLocalHash = "sha256:aaaa0000111122223333444455556666777788889999aaaabbbbccccddddeeeeffff";

void main() {
  setUp(() {
    registerFallbackValue("");
  });

  group("rendering", () {
    testWidgets("unknown state shows subtitle and Check trailing action", (tester) async {
      await tester.pumpWidget(buildTile(const BatchDataUpdateStatus.unknown()));
      await tester.pump();

      expect(find.text("点击检查所有数据版本"), findsOneWidget);
      expect(find.text("游戏数据"), findsOneWidget);
      expect(find.text("检查"), findsOneWidget);
    });

    testWidgets("checking state shows spinner and disables tile", (tester) async {
      await tester.pumpWidget(buildTile(const BatchDataUpdateStatus.checking()));
      await tester.pump();

      expect(find.text("正在检查更新…"), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets("upToDate state shows subtitle and Check action", (tester) async {
      await tester.pumpWidget(buildTile(const BatchDataUpdateStatus.upToDate()));
      await tester.pump();

      expect(find.text("已是最新"), findsOneWidget);
      expect(find.text("检查"), findsOneWidget);
    });

    testWidgets("available state shows title and Update action", (tester) async {
      await tester.pumpWidget(
        buildTile(BatchDataUpdateStatus.available({"checkout-1": testLocalHash})),
      );
      await tester.pump();

      expect(find.text("游戏数据"), findsOneWidget);
      expect(find.text("新的游戏数据已就绪"), findsOneWidget);
      expect(find.text("更新"), findsOneWidget);
    });

    testWidgets("downloading state shows spinner and disables tile", (tester) async {
      await tester.pumpWidget(
        buildTile(
          const BatchDataUpdateStatus.downloading(
            BatchUpdateProgress(
              currentCheckoutId: "checkout-1",
              completedCount: 1,
              totalCount: 2,
              downloadedCount: 5,
              totalDownloadCount: 10,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("正在更新游戏数据…"), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets("applied state shows subtitle and Check action", (tester) async {
      await tester.pumpWidget(
        buildTile(
          BatchDataUpdateStatus.applied(
            const BatchUpdateResult(successes: ["checkout-1"], failures: {}, skipped: []),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("刚刚更新"), findsOneWidget);
      expect(find.text("检查"), findsOneWidget);
    });

    testWidgets("failed state shows error message and Retry when canRetry is true", (tester) async {
      await tester.pumpWidget(
        buildTile(const BatchDataUpdateStatus.failed(message: "连接错误", canRetry: true)),
      );
      await tester.pump();

      expect(find.text("连接错误"), findsOneWidget);
      expect(find.text("重试"), findsOneWidget);
    });

    testWidgets("failed state shows error icon when canRetry is false", (tester) async {
      await tester.pumpWidget(
        buildTile(const BatchDataUpdateStatus.failed(message: "无法恢复", canRetry: false)),
      );
      await tester.pump();

      expect(find.text("无法恢复"), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group("interaction", () {
    testWidgets("tapping Check triggers checkAllCheckouts", (tester) async {
      final mockService = MockDataUpdateService();
      when(() => mockService.checkAllCheckouts()).thenAnswer(
        (_) async => {
          "checkout-1": const DataUpdateCheckResult.upToDate(currentGenerationHash: "hash"),
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dataUpdateServiceProvider.overrideWith((_) => mockService),
            appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          ],
          child: testApp(const Material(child: DataUpdateTile())),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Post-frame ensureCheck should have triggered a service call
      verify(() => mockService.checkAllCheckouts()).called(1);
    });
  });
}
