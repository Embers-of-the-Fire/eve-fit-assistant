import "dart:convert";

import "package:eve_fit_assistant/features/announcements/models/models.dart";
import "package:flutter_test/flutter_test.dart";

const _sampleBundledCatalogJson = """
{
  "schemaVersion": 1,
  "pages": [
    {
      "uuid": "00000000-0000-0000-0000-000000000001",
      "publishedAt": "2026-06-01T00:00:00.000Z",
      "minAppVersion": "0.0.0",
      "channels": ["testing"],
      "count": 2,
      "active": true
    }
  ],
  "bundledPage": {
    "uuid": "00000000-0000-0000-0000-000000000001",
    "publishedAt": "2026-06-01T00:00:00.000Z",
    "maxEntries": 50,
    "entries": [
      {
        "id": "welcome",
        "publishedAt": "2026-04-14T00:00:00.000Z",
        "tags": ["welcome"],
        "startup": true,
        "minAppVersion": null,
        "maxAppVersion": null,
        "channels": ["testing"],
        "platforms": ["android", "ios"],
        "appVersion": null,
        "localizations": {
          "zh": {
            "title": "欢迎",
            "summary": "欢迎摘要。",
            "bodyHash": "aaaabbbbccccddddeeeeffff0000111122223333444455556666777788889999"
          },
          "en": {
            "title": "Welcome",
            "summary": "Welcome summary.",
            "bodyHash": "ffffaaaabbbbccccddddeeeeffff000011112222333344445555666677778888"
          }
        }
      },
      {
        "id": "version-2.0.0",
        "publishedAt": "2026-06-01T12:00:00.000Z",
        "tags": ["release-note"],
        "startup": false,
        "minAppVersion": null,
        "maxAppVersion": null,
        "channels": ["testing"],
        "platforms": ["android", "ios"],
        "appVersion": "2.0.0",
        "localizations": {
          "en": {
            "title": "Version 2.0.0",
            "summary": "Major update.",
            "bodyHash": "1111aaaabbbbccccddddeeeeffff000011112222333344445555666677778888"
          }
        }
      }
    ]
  }
}""";

void main() {
  group("Bundled catalog parsing", () {
    test("bundled catalog JSON parses correctly", () {
      final json = jsonDecode(_sampleBundledCatalogJson) as Map<String, dynamic>;
      final catalog = AnnouncementCatalog.fromJson(json);
      expect(catalog.schemaVersion, 1);
      expect(catalog.pages, hasLength(1));
      expect(catalog.pages.single.count, 2);
      expect(catalog.pages.single.active, isTrue);
      expect(catalog.pages.single.uuid, "00000000-0000-0000-0000-000000000001");
      expect(catalog.pages.single.channels, ["testing"]);
    });

    test("bundled page JSON parses AnnouncementPage correctly", () {
      final json = jsonDecode(_sampleBundledCatalogJson) as Map<String, dynamic>;
      final bundledPageJson = json["bundledPage"] as Map<String, dynamic>;
      final page = AnnouncementPage.fromJson(bundledPageJson);
      expect(page.uuid, "00000000-0000-0000-0000-000000000001");
      expect(page.entries, hasLength(2));
    });

    test("bundled entries have correct metadata", () {
      final json = jsonDecode(_sampleBundledCatalogJson) as Map<String, dynamic>;
      final bundledPageJson = json["bundledPage"] as Map<String, dynamic>;
      final page = AnnouncementPage.fromJson(bundledPageJson);

      final welcome = page.entries.firstWhere((e) => e.id == "welcome");
      expect(welcome.startup, isTrue);
      expect(welcome.appVersion, isNull);
      expect(welcome.tags, contains("welcome"));
      expect(welcome.channels, contains("testing"));
      expect(
        welcome.platforms,
        containsAll([AnnouncementPlatform.android, AnnouncementPlatform.ios]),
      );
      expect(welcome.localizations, contains("zh"));
      expect(welcome.localizations, contains("en"));

      final version = page.entries.firstWhere((e) => e.id == "version-2.0.0");
      expect(version.appVersion, "2.0.0");
      expect(version.startup, isFalse);
      expect(version.localizations, contains("en"));
      expect(version.localizations, isNot(contains("zh")));
    });

    test("entry locale resolution defaults to en", () {
      final json = jsonDecode(_sampleBundledCatalogJson) as Map<String, dynamic>;
      final bundledPageJson = json["bundledPage"] as Map<String, dynamic>;
      final page = AnnouncementPage.fromJson(bundledPageJson);

      final entry = page.entries.firstWhere((e) => e.id == "version-2.0.0");
      final resolved = entry.resolveLocalization("zh_CN");
      expect(resolved, isNotNull);
      expect(resolved!.localeCode, "en");
      expect(resolved.meta.title, "Version 2.0.0");
    });

    test("entry locale resolution matches zh_CN to zh", () {
      final json = jsonDecode(_sampleBundledCatalogJson) as Map<String, dynamic>;
      final bundledPageJson = json["bundledPage"] as Map<String, dynamic>;
      final page = AnnouncementPage.fromJson(bundledPageJson);

      final entry = page.entries.firstWhere((e) => e.id == "welcome");
      final resolved = entry.resolveLocalization("zh_CN");
      expect(resolved, isNotNull);
      expect(resolved!.localeCode, "zh");
      expect(resolved.meta.title, "欢迎");
    });

    test("entry locale resolution returns null when no locale available", () {
      final json = jsonDecode(_sampleBundledCatalogJson) as Map<String, dynamic>;
      final bundledPageJson = json["bundledPage"] as Map<String, dynamic>;
      final page = AnnouncementPage.fromJson(bundledPageJson);

      final entry = page.entries.firstWhere((e) => e.id == "version-2.0.0");
      // Remove all localizations
      final emptyEntry = entry.copyWith(localizations: <String, LocalizationMeta>{});
      expect(emptyEntry.resolveLocalization("ja"), isNull);
    });

    test("AnnouncementRecord from bundled entry has correct source", () {
      final json = jsonDecode(_sampleBundledCatalogJson) as Map<String, dynamic>;
      final bundledPageJson = json["bundledPage"] as Map<String, dynamic>;
      final page = AnnouncementPage.fromJson(bundledPageJson);

      final entry = page.entries.firstWhere((e) => e.id == "welcome");
      final resolved = entry.resolveLocalization("en");
      expect(resolved, isNotNull);

      final record = AnnouncementRecord(
        id: entry.id,
        source: AnnouncementEntrySource.bundled,
        title: resolved!.meta.title,
        summary: resolved.meta.summary,
        bodyHash: resolved.meta.bodyHash,
        publishedAt: entry.publishedAt,
        localeCode: resolved.localeCode,
        tags: entry.tags,
        startup: entry.startup,
        minAppVersion: entry.minAppVersion,
        maxAppVersion: entry.maxAppVersion,
        appVersion: entry.appVersion,
        isRead: false,
        isDismissed: false,
      );
      expect(record.source, AnnouncementEntrySource.bundled);
      expect(record.id, "welcome");
      expect(record.title, "Welcome");
      expect(record.startup, isTrue);
      expect(record.bodyHash, hasLength(64));
    });
  });
}
