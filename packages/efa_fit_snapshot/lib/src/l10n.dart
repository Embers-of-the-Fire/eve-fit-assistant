import "package:efa_fit_snapshot/src/l10n/generated/snapshot_localizations.dart";
import "package:flutter/widgets.dart";

export "package:efa_fit_snapshot/src/l10n/generated/snapshot_localizations.dart";

extension SnapshotL10nExt on BuildContext {
  SnapshotLocalizations get snapshotL10n => SnapshotLocalizations.of(this);
}

/// Resolves a display name from a snapshot `names` map (BCP-47 keyed).
///
/// Order: exact language tag → language code → `"en"` → first entry.
String resolveSnapshotName(Map<String, String> names, Locale locale) {
  if (names.isEmpty) return "";
  final tag = locale.toLanguageTag();
  if (names.containsKey(tag)) return names[tag]!;
  final language = locale.languageCode;
  if (names.containsKey(language)) return names[language]!;
  if (names.containsKey("en")) return names["en"]!;
  return names.values.first;
}
