import "package:eve_fit_assistant/features/manual/search/manual_search_text.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("normalizeSearchText", () {
    test("collapses whitespace and lowercases", () {
      expect(normalizeSearchText("  Fitting\n\tModules  Here "), "fitting modules here");
    });

    test("keeps CJK characters as-is", () {
      expect(normalizeSearchText(" 舰船 配置 "), "舰船 配置");
    });
  });

  group("buildTrigramMatchQuery", () {
    test("quotes the whole query as one phrase", () {
      expect(buildTrigramMatchQuery("舰船 配置"), '"舰船 配置"');
    });

    test("escapes embedded double quotes", () {
      expect(buildTrigramMatchQuery('say "hi"'), '"say ""hi"""');
    });
  });

  group("buildPorterMatchQuery", () {
    test("quotes terms and marks the last as prefix", () {
      expect(buildPorterMatchQuery("fitting modules"), '"fitting" "modules" *');
    });

    test("single term gets the prefix marker", () {
      expect(buildPorterMatchQuery("fitting"), '"fitting" *');
    });

    test("empty query produces an empty expression", () {
      expect(buildPorterMatchQuery(""), "");
    });
  });

  group("extractSnippet", () {
    test("centers a window around the match with ellipses", () {
      final body = "a" * 100 + "目标词" + "b" * 100;
      final snippet = extractSnippet(body, "目标词");
      expect(snippet.text, startsWith("…"));
      expect(snippet.text, endsWith("…"));
      expect(snippet.text, contains("目标词"));
      expect(snippet.ranges, hasLength(1));
      final range = snippet.ranges.first;
      expect(snippet.text.substring(range.start, range.end), "目标词");
    });

    test("no ellipsis when the whole body fits", () {
      final snippet = extractSnippet("这是短正文", "短正文");
      expect(snippet.text, "这是短正文");
      expect(snippet.ranges.first, (start: 2, end: 5));
    });

    test("falls back to individual query words", () {
      final snippet = extractSnippet("the quick brown fox jumps", "quickly fox");
      expect(snippet.ranges, hasLength(1));
      final range = snippet.ranges.first;
      expect(snippet.text.substring(range.start, range.end), "fox");
    });

    test("returns document start without ranges when nothing matches", () {
      final body = "x" * 200;
      final snippet = extractSnippet(body, "zzz");
      expect(snippet.text, "x" * 80 + "…");
      expect(snippet.ranges, isEmpty);
    });
  });

  group("titleMatchRanges", () {
    test("finds the full query", () {
      expect(titleMatchRanges("创建你的第一个配置", "第一个"), [(start: 4, end: 7)]);
    });

    test("falls back to individual words", () {
      expect(titleMatchRanges("browsing ships", "ship browser"), [(start: 9, end: 13)]);
    });

    test("empty when nothing matches", () {
      expect(titleMatchRanges("browsing ships", "zzz"), isEmpty);
    });
  });
}
