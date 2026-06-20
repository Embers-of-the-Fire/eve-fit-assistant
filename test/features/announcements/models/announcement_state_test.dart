import "dart:convert";

import "package:eve_fit_assistant/features/announcements/models/announcement_state.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("AnnouncementState", () {
    test("initial factory produces defaults", () {
      final state = AnnouncementState.initial();
      expect(state.schemaVersion, 1);
      expect(state.readIds, isEmpty);
      expect(state.dismissedIds, isEmpty);
      expect(state.lastSeenAppVersion, isNull);
    });

    test("JSON round-trip initial state", () {
      final state = AnnouncementState.initial();
      final restored = AnnouncementState.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
      );
      expect(restored, state);
      expect(restored.schemaVersion, 1);
      expect(restored.readIds, isEmpty);
    });

    test("JSON round-trip with data", () {
      final state = AnnouncementState(
        schemaVersion: 1,
        readIds: ["entry-1", "entry-2"],
        dismissedIds: ["entry-3"],
        lastSeenAppVersion: "2.0.0",
      );
      final restored = AnnouncementState.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
      );
      expect(restored, state);
      expect(restored.readIds, ["entry-1", "entry-2"]);
      expect(restored.dismissedIds, ["entry-3"]);
      expect(restored.lastSeenAppVersion, "2.0.0");
    });

    test("deserialize from spec example announcement_state.json", () {
      const jsonStr =
          "{"
          '  "schemaVersion": 1,'
          '  "readIds": ["maintenance-2026-06"],'
          '  "dismissedIds": [],'
          '  "lastSeenAppVersion": "2.0.0"'
          "}";
      final state = AnnouncementState.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );
      expect(state.schemaVersion, 1);
      expect(state.readIds, ["maintenance-2026-06"]);
      expect(state.dismissedIds, isEmpty);
      expect(state.lastSeenAppVersion, "2.0.0");
    });
  });
}
