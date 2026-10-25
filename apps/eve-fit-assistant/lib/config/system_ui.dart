import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";

/// App-wide system UI policy.
///
/// EFA renders a permanently dark surface, so the system navigation bar is
/// transparent and uses light icons. On Android 10+ the app opts into
/// edge-to-edge explicitly; without it the area around the system gesture
/// handle stays outside the Flutter surface and is painted by the native
/// window theme, which can leave a white strip on light-themed OEM systems
/// and Android-compatible runtimes such as HarmonyOS.
abstract final class AppSystemUi {
  /// Fallback navigation-bar color for platforms that cannot draw edge-to-edge.
  ///
  /// This is the app's canonical page surface (`#101418`). It matches the
  /// Scaffold background and keeps the system bar dark when the Flutter view
  /// does not extend behind it (Android 9 and below).
  static const Color navigationBarFallbackColor = Color(0xFF101418);

  /// Overlay style for the app's dark surfaces.
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

  /// Picks the transparent style only when a bottom system inset is present,
  /// which means edge-to-edge is active and the app paints behind the gesture
  /// handle. Otherwise the system bar gets an opaque dark fallback.
  static SystemUiOverlayStyle overlayStyleFor(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).bottom > 0 ? overlayStyle : opaqueNavigationBarStyle;

  /// Enables edge-to-edge rendering on Android 10+.
  ///
  /// Android 15+ already enforces edge-to-edge for apps targeting SDK 35 or
  /// later, and Android 9 and below have no gesture navigation handle, so this
  /// is a no-op on those versions.
  static Future<void> apply() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}
