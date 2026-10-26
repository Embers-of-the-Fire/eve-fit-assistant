import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";

/// App-wide system UI policy.
///
/// EFA renders a permanently dark surface, so the system navigation bar uses
/// light icons. On Android 10+ the app opts into edge-to-edge explicitly and
/// makes the bar transparent; without edge-to-edge the area around the system
/// gesture handle stays outside the Flutter surface and is painted by the
/// native window theme, which can leave a white strip on light-themed OEM
/// systems and Android-compatible runtimes such as HarmonyOS.
abstract final class AppSystemUi {
  /// Channel that reports platform capabilities from the host activity.
  static const MethodChannel _platformChannel = MethodChannel(
    "dev.efa_tech.eve_fit_assistant/system_ui",
  );

  /// First Android API level where [SystemUiMode.edgeToEdge] takes effect.
  static const int _edgeToEdgeMinSdk = 29;

  /// Whether [apply] confirmed that the Flutter surface extends behind the
  /// system bars on this device.
  static bool _edgeToEdgeEnabled = false;

  /// Overrides the edge-to-edge state in tests.
  @visibleForTesting
  static set debugEdgeToEdgeEnabled(bool value) => _edgeToEdgeEnabled = value;

  /// Fallback navigation-bar color for platforms that cannot draw edge-to-edge.
  ///
  /// This is the app's canonical page surface (`#101418`). It matches the
  /// Scaffold background and keeps the system bar dark when the Flutter view
  /// does not extend behind it (Android 9 and below).
  static const Color navigationBarFallbackColor = Color(0xFF101418);

  /// Overlay style for the app's dark surfaces with a transparent navigation
  /// bar.
  ///
  /// The status bar fields are a fallback for routes without an [AppBar];
  /// [AppBar] still overrides them with its own annotated region.
  static const SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  /// Overlay style used when the Flutter view does not cover the navigation
  /// bar, where a transparent bar would reveal the native window background.
  static const SystemUiOverlayStyle opaqueNavigationBarStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: navigationBarFallbackColor,
    systemNavigationBarDividerColor: navigationBarFallbackColor,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  /// Picks the transparent style only when edge-to-edge is active and a bottom
  /// system inset is present, which means the app paints behind the gesture
  /// handle. Otherwise the system bar gets an opaque dark fallback.
  static SystemUiOverlayStyle overlayStyleFor(BuildContext context) =>
      _edgeToEdgeEnabled && MediaQuery.viewPaddingOf(context).bottom > 0
      ? overlayStyle
      : opaqueNavigationBarStyle;

  /// Enables edge-to-edge rendering on Android 10+.
  ///
  /// [SystemUiMode.edgeToEdge] only takes effect on Android 10 (API 29) and
  /// later. On API 28 and below the Flutter view does not draw behind the
  /// system bars, so a transparent navigation-bar color would expose the
  /// native window background and could leave light icons with insufficient
  /// contrast. The mode is therefore gated on the host-reported SDK level, and
  /// the opaque fallback stays in place when the level is missing or too old.
  static Future<void> apply() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    final sdkInt = await _readAndroidSdkInt();
    if (sdkInt == null || sdkInt < _edgeToEdgeMinSdk) {
      return;
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _edgeToEdgeEnabled = true;
  }

  /// Reads `android.os.Build.VERSION.SDK_INT` from the host activity.
  ///
  /// Returns null when the host does not implement the channel, so callers
  /// keep the opaque fallback instead of assuming edge-to-edge support.
  static Future<int?> _readAndroidSdkInt() async {
    try {
      return await _platformChannel.invokeMethod<int>("getSdkInt");
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint("Failed to read the Android SDK level: ${e.message}");
      return null;
    }
  }
}
