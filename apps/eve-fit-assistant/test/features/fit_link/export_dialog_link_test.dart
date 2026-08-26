import "dart:math";

import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/features/fit_io/export_dialog.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";

import "../../test_helpers.dart";

FitStorage _makeFit({String description = ""}) => FitStorage(
  metadata: FitMetadata(
    fitId: "test-fit-1",
    shipTypeId: 12017,
    name: "Test Fit",
    lastModified: 0,
    description: description,
    checkoutRef: const CheckoutRef(checkoutId: "checkout-abc", serverId: "Serenity"),
  ),
  body: const FitStorageBody(
    shipTypeId: 12017,
    characterId: "predefined_all_5",
    damageProfile: FitDamageProfile(em: 0.25, explosive: 0.25, kinetic: 0.25, thermal: 0.25),
    slots: FitStorageSlots(
      high: IList.empty(),
      medium: IList.empty(),
      low: IList.empty(),
      rig: IList.empty(),
      subsystem: IList.empty(),
      service: IList.empty(),
      tacticalMode: None(),
    ),
    drones: IList.empty(),
    fighters: IList.empty(),
    implants: IList.empty(),
    boosters: IList.empty(),
  ),
  dynamicRegistry: const FitDynamicRegistry(dynamicItems: IMap.empty()),
);

String _randomText(int length, int seed) {
  final random = Random(seed);
  const alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  return String.fromCharCodes(
    List.generate(length, (_) => alphabet.codeUnitAt(random.nextInt(alphabet.length))),
  );
}

void main() {
  final clipboardWrites = <String>[];

  setUp(() {
    clipboardWrites.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == "Clipboard.setData") {
          clipboardWrites.add((call.arguments as Map)["text"] as String);
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  Widget buildDialog(FitStorage fit) => ProviderScope(
    overrides: [
      appSettingServiceProvider.overrideWithValue(
        const AppSetting(
          locale: Locale.zh,
          enableDebugLog: false,
          shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
          showCheckoutImpactWarnings: true,
          typeListReturnBehavior: TypeListReturnBehavior.previousPage,
          developerMode: false,
        ),
      ),
    ],
    child: testApp(
      Scaffold(body: FitExportDialog(fitId: fit.metadata.fitId, initialFit: fit)),
    ),
  );

  testWidgets("copy link writes the share URL to the clipboard", (tester) async {
    await tester.pumpWidget(buildDialog(_makeFit()));
    await tester.pumpAndSettle();

    await tester.tap(find.text("复制链接"));
    await tester.pumpAndSettle();

    expect(clipboardWrites, hasLength(1));
    expect(
      clipboardWrites.single,
      startsWith("https://platform.efa-tech.dev/share/fit/raw?payload=EFA2:"),
    );
  });

  testWidgets("oversized fit shows the too-large notice and copies nothing", (tester) async {
    await tester.pumpWidget(buildDialog(_makeFit(description: _randomText(20000, 7))));
    await tester.pumpAndSettle();

    await tester.tap(find.text("复制链接"));
    await tester.pumpAndSettle();

    expect(clipboardWrites, isEmpty);
    expect(find.text("该配置过大，无法生成分享链接，请改用文本导出。"), findsOneWidget);
  });

  testWidgets("the export dialog no longer carries the platform share action", (tester) async {
    await tester.pumpWidget(buildDialog(_makeFit()));
    await tester.pumpAndSettle();

    // Text export actions only; platform sharing lives in the fit-list swipe
    // action and its dedicated dialog.
    for (final format in ["EFA 原生编码", "EFT 文本", "快照"]) {
      await tester.tap(find.text(format));
      await tester.pumpAndSettle();
      expect(find.text("分享"), findsNothing);
    }
  });
}
