import "package:eve_fit_assistant/features/announcements/models/announcement_entry.dart";
import "package:eve_fit_assistant/features/announcements/models/localization_meta.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("AnnouncementEntry.resolveLocalization", () {
    late AnnouncementEntry entry;

    setUp(() {
      entry = AnnouncementEntry(
        id: "test-entry",
        publishedAt: DateTime.utc(2026, 6, 15, 8),
        channels: ["stable"],
        platforms: ["android"],
        localizations: {
          "zh_CN": LocalizationMeta(title: "中文标题", summary: "中文摘要", bodyHash: "hash_zh_cn"),
          "zh": LocalizationMeta(title: "中文标题(语言)", summary: "中文摘要(语言)", bodyHash: "hash_zh"),
          "en": LocalizationMeta(
            title: "English Title",
            summary: "English Summary",
            bodyHash: "hash_en",
          ),
        },
      );
    });

    test("exact locale match (zh_CN)", () {
      final result = entry.resolveLocalization("zh_CN");
      expect(result, isNotNull);
      expect(result!.localeCode, "zh_CN");
      expect(result.meta.bodyHash, "hash_zh_cn");
    });

    test("language fallback (zh_HK → zh)", () {
      final result = entry.resolveLocalization("zh_HK");
      expect(result, isNotNull);
      expect(result!.localeCode, "zh");
      expect(result.meta.bodyHash, "hash_zh");
    });

    test("en fallback (fr → en)", () {
      final result = entry.resolveLocalization("fr");
      expect(result, isNotNull);
      expect(result!.localeCode, "en");
      expect(result.meta.bodyHash, "hash_en");
    });

    test("first-key fallback (only non-en locales, user zh_CN exact match)", () {
      final entryNoEn = AnnouncementEntry(
        id: "test-entry",
        publishedAt: DateTime.utc(2026, 6, 15, 8),
        channels: ["stable"],
        platforms: ["android"],
        localizations: {
          "ja": LocalizationMeta(title: "日本語タイトル", summary: "日本語要約", bodyHash: "hash_ja"),
        },
      );
      final result = entryNoEn.resolveLocalization("zh_CN");
      expect(result, isNotNull);
      expect(result!.localeCode, "ja");
      expect(result.meta.bodyHash, "hash_ja");
    });

    test("null when localizations is empty", () {
      final entryEmpty = AnnouncementEntry(
        id: "test-entry",
        publishedAt: DateTime.utc(2026, 6, 15, 8),
        channels: ["stable"],
        platforms: ["android"],
        localizations: {},
      );
      final result = entryEmpty.resolveLocalization("zh_CN");
      expect(result, isNull);
    });

    test("normalizes - to _ in locale code", () {
      final result = entry.resolveLocalization("zh-CN");
      expect(result, isNotNull);
      expect(result!.localeCode, "zh_CN");
    });

    test("case insensitive locale matching", () {
      final result = entry.resolveLocalization("EN");
      expect(result, isNotNull);
      expect(result!.localeCode, "en");
    });
  });
}
