import "dart:convert";

enum DocumentEntryKind { announcement, version }

enum DocumentEntrySource { bundled, remote }

enum DocumentFeedKind { mixed, version }

extension DocumentFeedKindStorageKey on DocumentFeedKind {
  String get storageKey => switch (this) {
    DocumentFeedKind.mixed => "mixed",
    DocumentFeedKind.version => "version",
  };
}

class DocumentLocalization {
  const DocumentLocalization({
    required this.title,
    required this.summary,
    this.bodyAssetPath,
    this.bodyMarkdown,
  });

  factory DocumentLocalization.fromJson(Map<String, dynamic> json) => DocumentLocalization(
    title: json["title"] as String,
    summary: json["summary"] as String,
    bodyAssetPath: json["bodyAssetPath"] as String?,
    bodyMarkdown: json["bodyMarkdown"] as String?,
  );

  final String title;
  final String summary;
  final String? bodyAssetPath;
  final String? bodyMarkdown;

  Map<String, dynamic> toJson() => <String, dynamic>{
    "title": title,
    "summary": summary,
    if (bodyAssetPath != null) "bodyAssetPath": bodyAssetPath,
    if (bodyMarkdown != null) "bodyMarkdown": bodyMarkdown,
  };
}

class DocumentEntry {
  const DocumentEntry({
    required this.id,
    required this.kind,
    required this.source,
    required this.publishedAt,
    required this.priority,
    required this.localizations,
    this.appVersion,
  });

  factory DocumentEntry.fromJson(Map<String, dynamic> json) {
    final localizationsJson = json["localizations"] as Map<String, dynamic>;
    return DocumentEntry(
      id: json["id"] as String,
      kind: DocumentEntryKind.values.byName(json["kind"] as String),
      source: DocumentEntrySource.values.byName(json["source"] as String),
      publishedAt: DateTime.parse(json["publishedAt"] as String),
      priority: json["priority"] as int? ?? 0,
      appVersion: json["appVersion"] as String?,
      localizations: <String, DocumentLocalization>{
        for (final MapEntry<String, dynamic> entry in localizationsJson.entries)
          entry.key: DocumentLocalization.fromJson(entry.value as Map<String, dynamic>),
      },
    );
  }

  final String id;
  final DocumentEntryKind kind;
  final DocumentEntrySource source;
  final DateTime publishedAt;
  final int priority;
  final String? appVersion;
  final Map<String, DocumentLocalization> localizations;

  Map<String, dynamic> toJson() => <String, dynamic>{
    "id": id,
    "kind": kind.name,
    "source": source.name,
    "publishedAt": publishedAt.toIso8601String(),
    "priority": priority,
    if (appVersion != null) "appVersion": appVersion,
    "localizations": <String, dynamic>{
      for (final MapEntry<String, DocumentLocalization> entry in localizations.entries)
        entry.key: entry.value.toJson(),
    },
  };

  DocumentLocalization? resolveLocalization(String localeCode) {
    final normalizedCode = localeCode.toLowerCase();
    return localizations[normalizedCode] ??
        localizations[normalizedCode.split("_").first] ??
        localizations["en"] ??
        localizations["zh"];
  }
}

class DocumentCatalog {
  const DocumentCatalog({required this.version, required this.entries});

  factory DocumentCatalog.empty() => const DocumentCatalog(version: 1, entries: <DocumentEntry>[]);

  factory DocumentCatalog.fromJson(Map<String, dynamic> json) => DocumentCatalog(
    version: json["version"] as int,
    entries: ((json["entries"] as List<dynamic>?) ?? const <dynamic>[])
        .map((entry) => DocumentEntry.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false),
  );

  factory DocumentCatalog.fromJsonText(String text) =>
      DocumentCatalog.fromJson(jsonDecode(text) as Map<String, dynamic>);

  final int version;
  final List<DocumentEntry> entries;

  Map<String, dynamic> toJson() => <String, dynamic>{
    "version": version,
    "entries": entries.map((DocumentEntry entry) => entry.toJson()).toList(growable: false),
  };
}

class DocumentRecord {
  const DocumentRecord({
    required this.id,
    required this.kind,
    required this.source,
    required this.title,
    required this.summary,
    required this.markdown,
    required this.publishedAt,
    required this.priority,
    required this.localeCode,
    this.appVersion,
  });

  final String id;
  final DocumentEntryKind kind;
  final DocumentEntrySource source;
  final String title;
  final String summary;
  final String markdown;
  final DateTime publishedAt;
  final int priority;
  final String localeCode;
  final String? appVersion;
}
