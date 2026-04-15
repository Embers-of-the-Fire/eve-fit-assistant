import "dart:convert";

import "package:freezed_annotation/freezed_annotation.dart";

part "models.freezed.dart";
part "models.g.dart";

enum DocumentEntryKind { announcement, version }

enum DocumentEntrySource { bundled, remote }

enum DocumentFeedKind { announcement, version }

extension DocumentFeedKindStorageKey on DocumentFeedKind {
  String get storageKey => switch (this) {
    DocumentFeedKind.announcement => "mixed",
    DocumentFeedKind.version => "version",
  };
}

@freezed
abstract class DocumentLocalization with _$DocumentLocalization {
  const factory DocumentLocalization({
    required String title,
    required String summary,
    String? bodyAssetPath,
    String? bodyMarkdown,
  }) = _DocumentLocalization;

  factory DocumentLocalization.fromJson(Map<String, dynamic> json) =>
      _$DocumentLocalizationFromJson(json);
}

@freezed
abstract class DocumentEntry with _$DocumentEntry {
  const factory DocumentEntry({
    required String id,
    required DocumentEntryKind kind,
    required DocumentEntrySource source,
    required DateTime publishedAt,
    required Map<String, DocumentLocalization> localizations,
    @Default(<String>[]) List<String> tags,
    String? minAppVer,
    String? appVer,
  }) = _DocumentEntry;

  factory DocumentEntry.fromJson(Map<String, dynamic> json) => _$DocumentEntryFromJson(json);

  const DocumentEntry._();

  ({String localeCode, DocumentLocalization localization})? resolveLocalization(String localeCode) {
    final normalizedCode = localeCode.toLowerCase().replaceAll("-", "_");
    final languageCode = normalizedCode.split("_").first;
    final resolvedLocaleCode = switch (normalizedCode) {
      final code when localizations.containsKey(code) => code,
      _ when localizations.containsKey(languageCode) => languageCode,
      _ when localizations.containsKey("en") => "en",
      _ when localizations.containsKey("zh") => "zh",
      _ => null,
    };
    if (resolvedLocaleCode == null) {
      return null;
    }
    return (localeCode: resolvedLocaleCode, localization: localizations[resolvedLocaleCode]!);
  }
}

@freezed
abstract class DocumentCatalog with _$DocumentCatalog {
  const factory DocumentCatalog({
    required int version,
    @Default(<DocumentEntry>[]) List<DocumentEntry> entries,
  }) = _DocumentCatalog;

  factory DocumentCatalog.empty() => const DocumentCatalog(version: 1);

  factory DocumentCatalog.fromJson(Map<String, dynamic> json) => _$DocumentCatalogFromJson(json);

  factory DocumentCatalog.fromJsonText(String text) =>
      DocumentCatalog.fromJson(jsonDecode(text) as Map<String, dynamic>);
}

@freezed
abstract class DocumentRecord with _$DocumentRecord {
  const factory DocumentRecord({
    required String id,
    required DocumentEntryKind kind,
    required DocumentEntrySource source,
    required String title,
    required String summary,
    required String markdown,
    required DateTime publishedAt,
    required String localeCode,
    @Default(<String>[]) List<String> tags,
    String? minAppVer,
    String? appVer,
  }) = _DocumentRecord;
}
