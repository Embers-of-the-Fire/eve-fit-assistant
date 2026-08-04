@TestOn("browser")
library;

import "dart:typed_data";

import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/storage/repo/resource_policy.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("resource index platform gate on web", () {
    test("rejects pre-policy indexes", () {
      final v1 = ResourceIndex()..schemaVersion = 1;

      expect(
        () => decodeResourceIndex(Uint8List.fromList(v1.writeToBuffer())),
        throwsA(isA<UnsupportedResourceIndexError>()),
      );
    });

    test("accepts policy-aware indexes", () {
      final v2 = ResourceIndex()
        ..schemaVersion = 1
        ..formatVersion = kPolicyAwareResourceIndexFormatVersion;

      final decoded = decodeResourceIndex(Uint8List.fromList(v2.writeToBuffer()));
      expect(decoded.formatVersion, kPolicyAwareResourceIndexFormatVersion);
    });

    test("the schema_version (storage protocol) is not the gate", () {
      // Any schema_version is accepted; only the per-snapshot format_version
      // gates web.
      final v2 = ResourceIndex()
        ..schemaVersion = 1
        ..formatVersion = kPolicyAwareResourceIndexFormatVersion;

      expect(() => validateResourceIndexForPlatform(v2), returnsNormally);
    });
  });
}
