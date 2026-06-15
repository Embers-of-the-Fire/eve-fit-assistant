import "dart:convert";

import "package:eve_fit_assistant/storage/repo/models/asset_manifest.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("AssetManifest", () {
    test("JSON round-trip with files", () {
      final manifest = AssetManifest(
        assetsVersion: 1,
        files: IMap({
          "data/types.json": AssetFile(pathHash: "abcd1234", hash: "efgh5678", size: 1024),
          "data/items.json": AssetFile(pathHash: "ijkl9012", hash: "mnop3456", size: 2048),
        }),
      );
      final restored = AssetManifest.fromJson(
        jsonDecode(jsonEncode(manifest.toJson())) as Map<String, dynamic>,
      );
      expect(restored, manifest);
      expect(restored.files.length, 2);
    });

    test("JSON round-trip with empty files", () {
      final manifest = AssetManifest(assetsVersion: 1);
      final restored = AssetManifest.fromJson(
        jsonDecode(jsonEncode(manifest.toJson())) as Map<String, dynamic>,
      );
      expect(restored.files.isEmpty, isTrue);
      expect(restored, manifest);
    });

    test("fromJson with known shape", () {
      final json =
          jsonDecode(
                '{'
                '  "assetsVersion": 1,'
                '  "files": {'
                '    "data/types.json": {"pathHash": "abcd1234", "hash": "efgh5678", "size": 1024}'
                '  }'
                '}',
              )
              as Map<String, dynamic>;
      final manifest = AssetManifest.fromJson(json);
      expect(manifest.assetsVersion, 1);
      expect(manifest.files["data/types.json"]!.pathHash, "abcd1234");
      expect(manifest.files["data/types.json"]!.hash, "efgh5678");
      expect(manifest.files["data/types.json"]!.size, 1024);
    });
  });
}
