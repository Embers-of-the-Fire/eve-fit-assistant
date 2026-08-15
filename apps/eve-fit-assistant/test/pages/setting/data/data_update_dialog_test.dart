import "dart:async";

import "package:eve_fit_assistant/pages/setting/data/data_update_dialog.dart";
import "package:eve_fit_assistant/storage/repo/data_update_service.dart";
import "package:eve_fit_assistant/storage/repo/data_update_status.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";

import "../../../test_helpers.dart";

class MockDataUpdateService extends Mock implements DataUpdateService {}

/// A fixed controller for rendering-only tests.
class _FixedCheckoutController extends CheckoutUpdateController {
  _FixedCheckoutController(this.initialStatus);

  final DataUpdateStatus initialStatus;

  @override
  DataUpdateStatus build(String checkoutId) => initialStatus;

  @override
  Future<void> check() async {}

  @override
  Future<void> apply() async {}
}

Future<void> _pumpDialog(WidgetTester tester, DataUpdateStatus status) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        checkoutUpdateControllerProvider("c1").overrideWith(() => _FixedCheckoutController(status)),
      ],
      child: testApp(const CheckoutDataUpdateOperationDialog(checkoutId: "c1")),
    ),
  );
  await tester.pump();
}

void main() {
  group("CheckoutDataUpdateOperationDialog", () {
    testWidgets("unknown/checking shows progress indicator", (tester) async {
      await _pumpDialog(tester, const DataUpdateStatus.unknown());

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text("正在检查更新…"), findsWidgets);
    });

    testWidgets("upToDate shows done button", (tester) async {
      await _pumpDialog(tester, const DataUpdateStatus.upToDate(currentGenerationHash: "hash"));

      expect(find.text("已是最新"), findsWidgets);
      expect(find.text("完成"), findsOneWidget);
    });

    testWidgets("available shows update button", (tester) async {
      await _pumpDialog(
        tester,
        const DataUpdateStatus.available(currentGenerationHash: "old", newGenerationHash: "new"),
      );

      expect(find.text("更新数据版本？"), findsOneWidget);
      expect(find.text("更新"), findsOneWidget);
    });

    testWidgets("failed shows error and retry when canRetry", (tester) async {
      await _pumpDialog(
        tester,
        const DataUpdateStatus.failed(message: "network error", canRetry: true),
      );

      expect(find.textContaining("network error"), findsOneWidget);
      expect(find.text("重试"), findsOneWidget);
    });

    testWidgets("controller.check surfaces thrown exceptions as failed", (tester) async {
      final mockService = MockDataUpdateService();
      when(() => mockService.checkForCheckout(any())).thenThrow(Exception("remote exploded"));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [dataUpdateServiceProvider.overrideWith((_) => mockService)],
          child: testApp(const CheckoutDataUpdateOperationDialog(checkoutId: "c1")),
        ),
      );
      await tester.pump();

      // Dialog starts in the checking state.
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CheckoutDataUpdateOperationDialog)),
      );
      final controller = container.read(checkoutUpdateControllerProvider("c1").notifier);
      await controller.check();
      await tester.pump();

      // After the exception the controller must transition to failed.
      expect(find.textContaining("remote exploded"), findsOneWidget);
      expect(find.text("重试"), findsOneWidget);
    });
  });
}
