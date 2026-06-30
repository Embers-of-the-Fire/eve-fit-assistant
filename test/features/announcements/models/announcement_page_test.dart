import "dart:convert";

import "package:eve_fit_assistant/features/announcements/models/announcement_entry.dart";
import "package:eve_fit_assistant/features/announcements/models/announcement_page.dart";
import "package:eve_fit_assistant/features/announcements/models/localization_meta.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("AnnouncementPage", () {
    test("JSON round-trip empty page", () {
      final page = AnnouncementPage(uuid: "test-uuid", publishedAt: DateTime.utc(2026, 6, 18));
      final restored = AnnouncementPage.fromJson(
        jsonDecode(jsonEncode(page.toJson())) as Map<String, dynamic>,
      );
      expect(restored, page);
      expect(restored.maxEntries, 50);
      expect(restored.entries, isEmpty);
    });

    test("JSON round-trip with entries", () {
      final page = AnnouncementPage(
        uuid: "f6e5d4c3-b2a1-0987-fedc-ba0987654321",
        publishedAt: DateTime.utc(2026, 6, 18),
        entries: [
          AnnouncementEntry(
            id: "test-1",
            publishedAt: DateTime.utc(2026, 6, 15, 8),
            channels: ["stable"],
            platforms: ["android"],
            localizations: {
              "en": LocalizationMeta(
                title: "Test Title",
                summary: "Test Summary",
                bodyHash: "abc123",
              ),
            },
          ),
        ],
      );
      final restored = AnnouncementPage.fromJson(
        jsonDecode(jsonEncode(page.toJson())) as Map<String, dynamic>,
      );
      expect(restored, page);
      expect(restored.entries.single.id, "test-1");
    });

    test("deserialize spec example active.json", () {
      const jsonStr =
          "{"
          '  "uuid": "f6e5d4c3-b2a1-0987-fedc-ba0987654321",'
          '  "publishedAt": "2026-06-18T00:00:00.000Z",'
          '  "maxEntries": 50,'
          '  "entries": ['
          '    {'
          '      "id": "maintenance-2026-06",'
          '      "publishedAt": "2026-06-15T08:00:00.000Z",'
          '      "tags": ["maintenance", "downtime"],'
          '      "startup": false,'
          '      "minAppVersion": "1.5.0",'
          '      "maxAppVersion": null,'
          '      "channels": ["stable", "beta"],'
          '      "platforms": ["android", "ios"],'
          '      "appVersion": null,'
          '      "localizations": {'
          '        "en": {'
          '          "title": "Scheduled Maintenance on June 20",'
          '          "summary": "Servers will be offline from 08:00 to 12:00 UTC.",'
          '          "bodyHash": "a1b2c3d4e5f6789012345678901234567890abcd12345678901234567890abcdef"'
          '        },'
          '        "zh": {'
          '          "title": "6月20日计划维护",'
          '          "summary": "服务器将于UTC时间08:00至12:00离线。",'
          '          "bodyHash": "fedcba098765432109876543210fedcba0987654321fedcba09876543210987654321"'
          '        }'
          '      }'
          '    },'
          '    {'
          '      "id": "version-2-0-0",'
          '      "publishedAt": "2026-06-10T12:00:00.000Z",'
          '      "tags": ["release"],'
          '      "startup": false,'
          '      "minAppVersion": null,'
          '      "maxAppVersion": null,'
          '      "channels": ["stable"],'
          '      "platforms": ["android", "ios"],'
          '      "appVersion": "2.0.0",'
          '      "localizations": {'
          '        "en": {'
          '          "title": "Version 2.0.0 Available",'
          '          "summary": "Major update with new feature X and performance improvements.",'
          '          "bodyHash": "b3c4d5e6f7a8901234567890123456789012345678abcd12345678901234567890ef"'
          '        }'
          '      }'
          '    }'
          '  ]'
          "}";
      final page = AnnouncementPage.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      expect(page.uuid, "f6e5d4c3-b2a1-0987-fedc-ba0987654321");
      expect(page.maxEntries, 50);
      expect(page.entries, hasLength(2));

      final entry1 = page.entries[0];
      expect(entry1.id, "maintenance-2026-06");
      expect(entry1.tags, ["maintenance", "downtime"]);
      expect(entry1.startup, isFalse);
      expect(entry1.minAppVersion, "1.5.0");
      expect(entry1.maxAppVersion, isNull);
      expect(entry1.channels, ["stable", "beta"]);
      expect(entry1.platforms, ["android", "ios"]);
      expect(entry1.appVersion, isNull);
      expect(entry1.localizations, hasLength(2));
      expect(entry1.localizations["en"]!.title, "Scheduled Maintenance on June 20");
      expect(entry1.localizations["zh"]!.title, "6月20日计划维护");

      final entry2 = page.entries[1];
      expect(entry2.id, "version-2-0-0");
      expect(entry2.appVersion, "2.0.0");
      expect(entry2.localizations, hasLength(1));
      expect(entry2.localizations["en"]!.title, "Version 2.0.0 Available");
    });

    test("page round-trip through catalog-like deserialization", () {
      final page = AnnouncementPage(
        uuid: "test-uuid",
        publishedAt: DateTime.utc(2026, 1, 1),
        maxEntries: 50,
        entries: [
          AnnouncementEntry(
            id: "entry-1",
            publishedAt: DateTime.utc(2026, 1, 1),
            channels: ["stable"],
            platforms: ["android"],
            localizations: {
              "en": LocalizationMeta(title: "Test", summary: "Summary", bodyHash: "hash"),
            },
          ),
        ],
      );
      final restored = AnnouncementPage.fromJson(
        jsonDecode(jsonEncode(page.toJson())) as Map<String, dynamic>,
      );
      expect(restored, page);
    });
  });
}
