import "dart:convert";

import "package:eve_fit_assistant/features/announcements/models/announcement_catalog.dart";
import "package:eve_fit_assistant/features/announcements/models/page_summary.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("AnnouncementCatalog", () {
    test("empty catalog factory", () {
      final catalog = AnnouncementCatalog.empty();
      expect(catalog.schemaVersion, 1);
      expect(catalog.pages, isEmpty);
    });

    test("JSON round-trip empty catalog", () {
      final catalog = AnnouncementCatalog.empty();
      final restored = AnnouncementCatalog.fromJson(
        jsonDecode(jsonEncode(catalog.toJson())) as Map<String, dynamic>,
      );
      expect(restored, catalog);
      expect(restored.schemaVersion, 1);
      expect(restored.pages, isEmpty);
    });

    test("JSON round-trip with pages", () {
      final catalog = AnnouncementCatalog(
        schemaVersion: 1,
        pages: [
          PageSummary(
            uuid: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
            publishedAt: DateTime.utc(2026, 6, 15),
            minAppVersion: "2.0.0",
            channels: ["stable", "beta"],
            count: 30,
            active: false,
          ),
        ],
      );
      final restored = AnnouncementCatalog.fromJson(
        jsonDecode(jsonEncode(catalog.toJson())) as Map<String, dynamic>,
      );
      expect(restored, catalog);
      expect(restored.pages.single.uuid, "a1b2c3d4-e5f6-7890-abcd-ef1234567890");
      expect(restored.pages.single.count, 30);
    });

    test("deserialize spec example catalog.json", () {
      const jsonStr =
          "{"
          '  "schemaVersion": 1,'
          '  "pages": ['
          '    {'
          '      "uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",'
          '      "publishedAt": "2026-06-15T00:00:00.000Z",'
          '      "minAppVersion": "2.0.0",'
          '      "channels": ["stable", "beta"],'
          '      "count": 30,'
          '      "active": false'
          '    },'
          '    {'
          '      "uuid": "f6e5d4c3-b2a1-0987-fedc-ba0987654321",'
          '      "publishedAt": "2026-06-18T00:00:00.000Z",'
          '      "minAppVersion": "1.5.0",'
          '      "channels": ["stable"],'
          '      "count": 12,'
          '      "active": true'
          '    }'
          '  ]'
          "}";
      final catalog = AnnouncementCatalog.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );
      expect(catalog.schemaVersion, 1);
      expect(catalog.pages, hasLength(2));
      expect(catalog.pages[0].uuid, "a1b2c3d4-e5f6-7890-abcd-ef1234567890");
      expect(catalog.pages[0].minAppVersion, "2.0.0");
      expect(catalog.pages[0].channels, ["stable", "beta"]);
      expect(catalog.pages[0].count, 30);
      expect(catalog.pages[0].active, isFalse);
      expect(catalog.pages[1].uuid, "f6e5d4c3-b2a1-0987-fedc-ba0987654321");
      expect(catalog.pages[1].active, isTrue);
    });
  });
}
