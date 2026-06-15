import "dart:convert";

import "package:eve_fit_assistant/storage/repo/models/release.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("ReleaseItemRecord", () {
    test("JSON round-trip with single platform", () {
      final record = ReleaseItemRecord(
        id: "rel-001",
        createdAt: "2024-01-15T00:00:00Z",
        version: "2.0.0",
        versionUpdateAnnouncement: "ann-001",
        files: IMap<String, IMap<String, String>>({
          "apk": IMap<String, String>({"combined": "hash-apk-combined-001"}),
        }),
      );
      final restored = ReleaseItemRecord.fromJson(
        jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>,
      );
      expect(restored, record);
    });

    test("JSON round-trip with multiple platforms", () {
      final record = ReleaseItemRecord(
        id: "rel-002",
        createdAt: "2024-01-16T00:00:00Z",
        version: "2.1.0",
        versionUpdateAnnouncement: "ann-002",
        files: IMap<String, IMap<String, String>>({
          "apk": IMap<String, String>({
            "arm64": "hash-apk-arm64-002",
            "x86_64": "hash-apk-x86_64-002",
            "combined": "hash-apk-combined-002",
          }),
        }),
      );
      final restored = ReleaseItemRecord.fromJson(
        jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>,
      );
      expect(restored, record);
      expect(restored.files["apk"]?["arm64"], "hash-apk-arm64-002");
      expect(restored.files["apk"]?["x86_64"], "hash-apk-x86_64-002");
    });

    test("JSON round-trip with empty files", () {
      final record = ReleaseItemRecord(
        id: "rel-003",
        createdAt: "2024-01-17T00:00:00Z",
        version: "2.2.0",
        versionUpdateAnnouncement: "ann-003",
      );
      final restored = ReleaseItemRecord.fromJson(
        jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>,
      );
      expect(restored, record);
    });

    test("fromJson with known shape", () {
      final json =
          jsonDecode(
                '{'
                '  "id": "rel-001",'
                '  "createdAt": "2024-01-15T00:00:00Z",'
                '  "version": "2.0.0",'
                '  "versionUpdateAnnouncement": "ann-001",'
                '  "files": {'
                '    "apk": {'
                '      "arm64": "hash-apk-arm64-001",'
                '      "combined": "hash-apk-combined-001"'
                '    }'
                '  }'
                '}',
              )
              as Map<String, dynamic>;
      final record = ReleaseItemRecord.fromJson(json);
      expect(record.id, "rel-001");
      expect(record.version, "2.0.0");
      expect(record.versionUpdateAnnouncement, "ann-001");
      expect(record.files["apk"]?["arm64"], "hash-apk-arm64-001");
      expect(record.files["apk"]?["combined"], "hash-apk-combined-001");
    });
  });
}
