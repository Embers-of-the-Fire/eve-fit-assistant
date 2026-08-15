import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:flutter/material.dart";

extension ContextExt on BuildContext {
  ThemeData get theme => Theme.of(this);
  AppLocalizations get l10n => AppLocalizations.of(this);
  NavigatorState get nav => Navigator.of(this);
  Locale get locale => Localizations.localeOf(this);
  MediaQueryData get mediaQuery => MediaQuery.of(this);
}
