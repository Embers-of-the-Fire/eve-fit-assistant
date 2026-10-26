@TestOn("vm")
library;

import "package:eve_fit_assistant/config/system_ui.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

const MethodChannel _systemUiChannel = MethodChannel("dev.efa_tech.eve_fit_assistant/system_ui");

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() => AppSystemUi.debugEdgeToEdgeEnabled = false);

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(_systemUiChannel, null);
  });

  List<MethodCall> mockSystemChromeCalls() {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    return calls;
  }

  void mockSdkInt(int? value) {
    messenger.setMockMethodCallHandler(_systemUiChannel, (call) async {
      expect(call.method, "getSdkInt");
      return value;
    });
  }

  /// Runs [AppSystemUi.apply] as [platform] and restores the platform override
  /// before the test invariant check runs.
  Future<void> applyAs(TargetPlatform platform) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await AppSystemUi.apply();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Future<SystemUiOverlayStyle> pumpOverlayStyle(
    WidgetTester tester, {
    double bottomInset = 24,
  }) async {
    late SystemUiOverlayStyle style;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(viewPadding: EdgeInsets.only(bottom: bottomInset)),
        child: Builder(
          builder: (context) {
            style = AppSystemUi.overlayStyleFor(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return style;
  }

  test("navigation bar overlay uses light icons without a contrast scrim", () {
    expect(AppSystemUi.overlayStyle.systemNavigationBarColor, Colors.transparent);
    expect(AppSystemUi.overlayStyle.systemNavigationBarIconBrightness, Brightness.light);
    expect(AppSystemUi.overlayStyle.systemNavigationBarContrastEnforced, isFalse);
    expect(
      AppSystemUi.opaqueNavigationBarStyle.systemNavigationBarColor,
      AppSystemUi.navigationBarFallbackColor,
    );
  });

  testWidgets("uses a transparent navigation bar once edge-to-edge is active", (tester) async {
    AppSystemUi.debugEdgeToEdgeEnabled = true;

    final style = await pumpOverlayStyle(tester);

    expect(style.systemNavigationBarColor, Colors.transparent);
  });

  testWidgets("keeps the opaque fallback when edge-to-edge is not active", (tester) async {
    final style = await pumpOverlayStyle(tester);

    expect(style.systemNavigationBarColor, AppSystemUi.navigationBarFallbackColor);
  });

  testWidgets("keeps the opaque fallback without a bottom inset", (tester) async {
    AppSystemUi.debugEdgeToEdgeEnabled = true;

    final style = await pumpOverlayStyle(tester, bottomInset: 0);

    expect(style.systemNavigationBarColor, AppSystemUi.navigationBarFallbackColor);
  });

  testWidgets("apply opts Android 10+ into edge-to-edge", (tester) async {
    final calls = mockSystemChromeCalls();
    mockSdkInt(29);

    await applyAs(TargetPlatform.android);

    expect(calls.map((call) => call.method), contains("SystemChrome.setEnabledSystemUIMode"));
    final modeCall = calls.singleWhere(
      (call) => call.method == "SystemChrome.setEnabledSystemUIMode",
    );
    expect(modeCall.arguments, "SystemUiMode.edgeToEdge");
    expect((await pumpOverlayStyle(tester)).systemNavigationBarColor, Colors.transparent);
  });

  testWidgets("apply keeps the opaque fallback on Android 9 and below", (tester) async {
    final calls = mockSystemChromeCalls();
    mockSdkInt(28);

    await applyAs(TargetPlatform.android);

    expect(calls, isEmpty);
    expect(
      (await pumpOverlayStyle(tester)).systemNavigationBarColor,
      AppSystemUi.navigationBarFallbackColor,
    );
  });

  testWidgets("apply keeps the opaque fallback when the SDK level is unavailable", (tester) async {
    final calls = mockSystemChromeCalls();
    messenger.setMockMethodCallHandler(_systemUiChannel, (call) async {
      throw MissingPluginException();
    });

    await applyAs(TargetPlatform.android);

    expect(calls, isEmpty);
    expect(
      (await pumpOverlayStyle(tester)).systemNavigationBarColor,
      AppSystemUi.navigationBarFallbackColor,
    );
  });

  testWidgets("apply leaves non-Android platforms untouched", (tester) async {
    final calls = mockSystemChromeCalls();
    mockSdkInt(29);

    await applyAs(TargetPlatform.iOS);

    expect(calls, isEmpty);
    expect(
      (await pumpOverlayStyle(tester)).systemNavigationBarColor,
      AppSystemUi.navigationBarFallbackColor,
    );
  });
}
