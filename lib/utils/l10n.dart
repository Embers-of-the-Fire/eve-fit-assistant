import 'package:eve_fit_assistant/data/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

AppLocalizations l10n(BuildContext context) {
  return AppLocalizations.of(context);
}

extension L10N on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
