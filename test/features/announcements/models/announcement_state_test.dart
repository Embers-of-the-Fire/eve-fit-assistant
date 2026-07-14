import "dart:convert";

import "package:eve_fit_assistant/features/announcements/models/announcement_state.dart";
import "package:eve_fit_assistant/features/app_update/models/app_version_state.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("AnnouncementState", () {
    test("initial factory produces defaults", () {
      final state = AnnouncementState.initial();
      expect(state.schemaVersion, 1);
      expect(state.readIds, isEmpty);
      expect(state.dismissedIds, isEmpty);
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
      );
      final restored = AnnouncementState.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
      );
      expect(restored, state);
      expect(restored.readIds, ["entry-1", "entry-2"]);
      expect(restored.dismissedIds, ["entry-3"]);
    });

    test("deserialize from spec example announcement_state.json", () {
      const jsonStr =
          "{"
          '  "schemaVersion": 1,'
          '  "readIds": ["maintenance-2026-06"],'
          '  "dismissedIds": []'
          "}";
      final state = AnnouncementState.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      expect(state.schemaVersion, 1);
      expect(state.readIds, ["maintenance-2026-06"]);
      expect(state.dismissedIds, isEmpty);
    });
  });

  group("AppVersionState", () {
    test("initial factory produces defaults", () {
      final state = AppVersionState.initial();
      expect(state.schemaVersion, 1);
      expect(state.lastSeenAppVersion, isNull);
      expect(state.lastAcknowledgedReleaseId, isNull);
    });

    test("JSON round-trip with data", () {
      const state = AppVersionState(
        schemaVersion: 1,
        lastSeenAppVersion: "2.0.0",
        lastAcknowledgedReleaseId: "release-123",
      );
      final restored = AppVersionState.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
      );
      expect(restored, state);
      expect(restored.lastSeenAppVersion, "2.0.0");
      expect(restored.lastAcknowledgedReleaseId, "release-123");
    });
  });
}
