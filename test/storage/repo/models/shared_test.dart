import "dart:convert";

import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("VersionRange", () {
    test("JSON round-trip with both fields", () {
      const range = VersionRange(min: "1.0.0", max: "2.0.0");
      final restored = VersionRange.fromJson(
        jsonDecode(jsonEncode(range.toJson())) as Map<String, dynamic>,
      );
      expect(restored, range);
    });

    test("JSON round-trip with one bound set", () {
      const range = VersionRange(min: "1.0.0");
      final restored = VersionRange.fromJson(
        jsonDecode(jsonEncode(range.toJson())) as Map<String, dynamic>,
      );
      expect(restored, range);
      expect(restored.min, "1.0.0");
      expect(restored.max, isNull);
    });

    test("JSON round-trip with null fields", () {
      const range = VersionRange();
      final restored = VersionRange.fromJson(
        jsonDecode(jsonEncode(range.toJson())) as Map<String, dynamic>,
      );
      expect(restored.min, isNull);
      expect(restored.max, isNull);
    });
  });

  group("AssetFile", () {
    test("JSON round-trip", () {
      const file = AssetFile(pathHash: "abcd1234", hash: "efgh5678", size: 1024);
      final restored = AssetFile.fromJson(
        jsonDecode(jsonEncode(file.toJson())) as Map<String, dynamic>,
      );
      expect(restored, file);
    });

    test("fromJson with known shape", () {
      final json =
          jsonDecode('{"pathHash":"abcd1234","hash":"efgh5678","size":1024}')
              as Map<String, dynamic>;
      final file = AssetFile.fromJson(json);
      expect(file.pathHash, "abcd1234");
      expect(file.hash, "efgh5678");
      expect(file.size, 1024);
    });
  });
}
