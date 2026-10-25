@TestOn("vm")
library;

import "package:eve_fit_assistant/config/system_ui.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test("navigation bar is transparent and uses light icons", () {
    expect(AppSystemUi.overlayStyle.systemNavigationBarColor, Colors.transparent);
    expect(AppSystemUi.overlayStyle.systemNavigationBarIconBrightness, Brightness.light);
    expect(AppSystemUi.overlayStyle.systemNavigationBarContrastEnforced, isFalse);
  });

  testWidgets("uses transparent navigation bar when a bottom inset is present", (tester) async {
    late SystemUiOverlayStyle style;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(viewPadding: EdgeInsets.only(bottom: 24)),
        child: Builder(
          builder: (context) {
            style = AppSystemUi.overlayStyleFor(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(style.systemNavigationBarColor, Colors.transparent);
  });

  testWidgets("falls back to an opaque dark bar without a bottom inset", (tester) async {
    late SystemUiOverlayStyle style;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Builder(
          builder: (context) {
            style = AppSystemUi.overlayStyleFor(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(style.systemNavigationBarColor, AppSystemUi.navigationBarFallbackColor);
  });

  test("apply opts Android into edge-to-edge", () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });

    await AppSystemUi.apply();

    expect(calls.map((call) => call.method), contains("SystemChrome.setEnabledSystemUIMode"));
    final modeCall = calls.singleWhere(
      (call) => call.method == "SystemChrome.setEnabledSystemUIMode",
    );
    expect(modeCall.arguments, "SystemUiMode.edgeToEdge");
  });

  test("apply leaves non-Android platforms untouched", () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });

    await AppSystemUi.apply();

    expect(calls, isEmpty);
  });
}
