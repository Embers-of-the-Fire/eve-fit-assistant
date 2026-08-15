import "dart:convert";

import "package:eve_fit_assistant/storage/repo/models/missing_files.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("MissingFiles", () {
    test("JSON round-trip with both lists empty", () {
      final result = MissingFiles();
      final restored = MissingFiles.fromJson(
        jsonDecode(jsonEncode(result.toJson())) as Map<String, dynamic>,
      );
      expect(restored, result);
      expect(restored.missing.isEmpty, isTrue);
      expect(restored.hashMismatches.isEmpty, isTrue);
    });

    test("JSON round-trip with missing files only", () {
      final result = MissingFiles(missing: IList(["data/items.json", "data/types.json"]));
      final restored = MissingFiles.fromJson(
        jsonDecode(jsonEncode(result.toJson())) as Map<String, dynamic>,
      );
      expect(restored, result);
      expect(restored.missing.length, 2);
      expect(restored.missing, contains("data/items.json"));
      expect(restored.missing, contains("data/types.json"));
      expect(restored.hashMismatches.isEmpty, isTrue);
    });

    test("JSON round-trip with hash mismatches only", () {
      final result = MissingFiles(hashMismatches: IList(["data/corrupt.json"]));
      final restored = MissingFiles.fromJson(
        jsonDecode(jsonEncode(result.toJson())) as Map<String, dynamic>,
      );
      expect(restored, result);
      expect(restored.missing.isEmpty, isTrue);
      expect(restored.hashMismatches.length, 1);
      expect(restored.hashMismatches, contains("data/corrupt.json"));
    });

    test("JSON round-trip with both missing and hash mismatches", () {
      final result = MissingFiles(
        missing: IList(["data/absent.json", "data/removed.json"]),
        hashMismatches: IList(["data/corrupt.json", "data/tampered.json"]),
      );
      final restored = MissingFiles.fromJson(
        jsonDecode(jsonEncode(result.toJson())) as Map<String, dynamic>,
      );
      expect(restored, result);
      expect(restored.missing.length, 2);
      expect(restored.hashMismatches.length, 2);
    });
  });
}
