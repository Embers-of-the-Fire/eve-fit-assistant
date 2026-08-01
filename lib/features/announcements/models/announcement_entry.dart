import "package:eve_fit_assistant/features/announcements/models/announcement_platform.dart";
import "package:eve_fit_assistant/features/announcements/models/localization_meta.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "announcement_entry.freezed.dart";
part "announcement_entry.g.dart";

@freezed
abstract class AnnouncementEntry with _$AnnouncementEntry {
  const factory AnnouncementEntry({
    required String id,
    required DateTime publishedAt,
    @Default(<String>[]) List<String> tags,
    @Default(false) bool startup,
    String? minAppVersion,
    String? maxAppVersion,
    @Default(<String>[]) List<String> channels,
    @Default(<AnnouncementPlatform>[])
    @JsonKey(unknownEnumValue: AnnouncementPlatform.unknown)
    List<AnnouncementPlatform> platforms,
    String? appVersion,
    @Default(<String, LocalizationMeta>{}) Map<String, LocalizationMeta> localizations,
  }) = _AnnouncementEntry;

  factory AnnouncementEntry.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementEntryFromJson(json);

  const AnnouncementEntry._();

  ({String localeCode, LocalizationMeta meta})? resolveLocalization(String localeCode) {
    final normalizedCode = localeCode.replaceAll("-", "_");
    final lowerKeys = <String, String>{
      for (final key in localizations.keys) key.toLowerCase(): key,
    };

    final exactKey = lowerKeys[normalizedCode.toLowerCase()];
    if (exactKey != null) {
      return (localeCode: exactKey, meta: localizations[exactKey]!);
    }

    final languagePrefix = normalizedCode.split("_").first.toLowerCase();
    final langKey = lowerKeys[languagePrefix];
    if (langKey != null) {
      return (localeCode: langKey, meta: localizations[langKey]!);
    }

    if (lowerKeys.containsKey("en")) {
      return (localeCode: "en", meta: localizations["en"]!);
    }

    final firstKey = localizations.keys.firstOrNull;
    if (firstKey != null) {
      return (localeCode: firstKey, meta: localizations[firstKey]!);
    }

    return null;
  }
}
