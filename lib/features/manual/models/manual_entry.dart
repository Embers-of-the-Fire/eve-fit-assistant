/// Localization payload for a single manual document.
class ManualDocLocalization {
  const ManualDocLocalization({
    required this.title,
    required this.summary,
    required this.contentFile,
  });

  final String title;
  final String summary;

  /// File name of the Markdown body under the bundled content directory,
  /// i.e. `{sha256("{docId}:{locale}")}.md`.
  final String contentFile;
}

/// A document in the manual tree.
class ManualDocEntry {
  const ManualDocEntry({required this.id, required this.order, required this.localizations});

  /// Path-joined id, e.g. `fitting/modules`.
  final String id;
  final int order;
  final Map<String, ManualDocLocalization> localizations;

  /// Resolve the localization for [localeCode]: exact match, language-prefix
  /// match, `en` fallback, then first available.
  ({String localeCode, ManualDocLocalization data})? resolveLocalization(String localeCode) {
    final key = resolveLocalizedKey(localizations, localeCode);
    if (key == null) return null;
    return (localeCode: key, data: localizations[key]!);
  }
}

/// A folder in the manual tree.
class ManualFolderEntry {
  const ManualFolderEntry({
    required this.id,
    required this.order,
    required this.names,
    required this.folders,
    required this.docs,
  });

  /// Path-joined id, e.g. `fitting`; empty for the root node.
  final String id;
  final int order;
  final Map<String, String> names;
  final List<ManualFolderEntry> folders;
  final List<ManualDocEntry> docs;

  /// Resolve the display name for [localeCode], following the same fallback
  /// chain as [ManualDocEntry.resolveLocalization].
  String? resolveName(String localeCode) {
    final key = resolveLocalizedKey(names, localeCode);
    return key == null ? null : names[key];
  }

  /// Depth-first traversal of every doc in this folder subtree, in tree order.
  Iterable<ManualDocEntry> get allDocs sync* {
    yield* docs;
    for (final folder in folders) {
      yield* folder.allDocs;
    }
  }

  /// Find a doc by its path-joined id within this folder subtree.
  ManualDocEntry? findDoc(String id) {
    for (final doc in allDocs) {
      if (doc.id == id) return doc;
    }
    return null;
  }
}

/// Shared locale fallback chain: exact match (after normalizing `-` to `_`,
/// case-insensitive), language-prefix match, `en`, then first key.
String? resolveLocalizedKey(Map<String, Object?> map, String localeCode) {
  final normalizedCode = localeCode.replaceAll("-", "_");
  final lowerKeys = <String, String>{for (final key in map.keys) key.toLowerCase(): key};

  final exactKey = lowerKeys[normalizedCode.toLowerCase()];
  if (exactKey != null) return exactKey;

  final languagePrefix = normalizedCode.split("_").first.toLowerCase();
  final langKey = lowerKeys[languagePrefix];
  if (langKey != null) return langKey;

  if (lowerKeys.containsKey("en")) return lowerKeys["en"];

  return map.keys.isEmpty ? null : map.keys.first;
}
