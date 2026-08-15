import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:flutter/material.dart";

/// Returns a minimal [MaterialApp] wrapping [child] with both Chinese and English
/// localizations for widget tests.
Widget testApp(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale("zh"),
  home: child,
);
