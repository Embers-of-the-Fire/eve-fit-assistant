/// A half-open character range `[start, end)` used to highlight matches.
typedef MatchRange = ({int start, int end});

/// A display snippet extracted from a document body.
class SearchSnippet {
  const SearchSnippet({required this.text, required this.ranges});

  /// The snippet text, possibly with leading/trailing ellipses.
  final String text;

  /// Match ranges within [text] to highlight.
  final List<MatchRange> ranges;
}

final RegExp _whitespacePattern = RegExp(r"\s+");

/// Normalize text the same way the search index was built: lowercase,
/// whitespace collapsed to single spaces. Mirrors
/// `bootstrap/docs/manual_search.py::normalize_search_text`.
String normalizeSearchText(String text) =>
    text.replaceAll(_whitespacePattern, " ").trim().toLowerCase();

/// Minimum normalized query length (in unicode characters) for a trigram
/// MATCH query; shorter queries use the LIKE fallback.
const int trigramMinQueryLength = 3;

/// Build an FTS5 MATCH expression for the trigram table: the whole query as
/// one quoted phrase, giving substring semantics.
String buildTrigramMatchQuery(String normalizedQuery) =>
    '"${normalizedQuery.replaceAll('"', '""')}"';

/// Build an FTS5 MATCH expression for the porter table: each whitespace-
/// separated term quoted (implicit AND), with a prefix marker on the last
/// term for as-you-type matching. Returns an empty string when no term can
/// produce a token.
String buildPorterMatchQuery(String normalizedQuery) {
  final terms = normalizedQuery
      .split(" ")
      .where((term) => term.isNotEmpty)
      .map((term) => '"${term.replaceAll('"', '""')}"')
      .toList();
  if (terms.isEmpty) return "";
  terms[terms.length - 1] = "${terms.last} *";
  return terms.join(" ");
}

/// Extract a display snippet of about [radius] characters around the first
/// match of [normalizedQuery] in [normalizedBody] (both already normalized).
///
/// When the full query is not a literal substring (e.g. stemmed English
/// matches), individual query words are tried in order; when nothing matches,
/// the document start is returned without highlight ranges.
SearchSnippet extractSnippet(String normalizedBody, String normalizedQuery, {int radius = 40}) {
  final needles = <String>[
    if (normalizedQuery.isNotEmpty) normalizedQuery,
    ...normalizedQuery.split(" ").where((term) => term.isNotEmpty),
  ];

  var matchIndex = -1;
  var matchLength = 0;
  for (final needle in needles) {
    matchIndex = normalizedBody.indexOf(needle);
    if (matchIndex >= 0) {
      matchLength = needle.length;
      break;
    }
  }

  if (matchIndex < 0) {
    final text = normalizedBody.length <= radius * 2
        ? normalizedBody
        : "${normalizedBody.substring(0, radius * 2)}…";
    return SearchSnippet(text: text, ranges: const []);
  }

  final start = matchIndex > radius ? matchIndex - radius : 0;
  final end = matchIndex + matchLength + radius < normalizedBody.length
      ? matchIndex + matchLength + radius
      : normalizedBody.length;
  final prefix = start > 0 ? "…" : "";
  final suffix = end < normalizedBody.length ? "…" : "";
  final rangeStart = prefix.length + matchIndex - start;
  return SearchSnippet(
    text: "$prefix${normalizedBody.substring(start, end)}$suffix",
    ranges: [(start: rangeStart, end: rangeStart + matchLength)],
  );
}

/// Find the highlight range of [normalizedQuery] within [normalizedTitle]
/// (both already normalized), trying individual words as a fallback.
List<MatchRange> titleMatchRanges(String normalizedTitle, String normalizedQuery) {
  final needles = <String>[
    if (normalizedQuery.isNotEmpty) normalizedQuery,
    ...normalizedQuery.split(" ").where((term) => term.isNotEmpty),
  ];
  for (final needle in needles) {
    final index = normalizedTitle.indexOf(needle);
    if (index >= 0) {
      return [(start: index, end: index + needle.length)];
    }
  }
  return const [];
}
