@TestOn("vm")
library;

import "dart:typed_data";

import "package:efa_proto/resource_index.pb.dart";
import "package:eve_fit_assistant/storage/repo/resource_policy.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("decodeResourceIndex on native", () {
    test("accepts pre-policy, policy-aware, and model-bearing indexes", () {
      final v1 = ResourceIndex()..schemaVersion = 1;
      final v2 = ResourceIndex()
        ..schemaVersion = 1
        ..formatVersion = kPolicyAwareResourceIndexFormatVersion;
      final v3 = ResourceIndex()
        ..schemaVersion = 1
        ..formatVersion = 3;

      expect(decodeResourceIndex(Uint8List.fromList(v1.writeToBuffer())).formatVersion, 1);
      expect(
        decodeResourceIndex(Uint8List.fromList(v2.writeToBuffer())).formatVersion,
        kPolicyAwareResourceIndexFormatVersion,
      );
      expect(decodeResourceIndex(Uint8List.fromList(v3.writeToBuffer())).formatVersion, 3);
    });

    test("rejects indexes beyond the maximum supported format", () {
      final v4 = ResourceIndex()
        ..schemaVersion = 1
        ..formatVersion = kMaxSupportedResourceIndexFormatVersion + 1;

      expect(
        () => decodeResourceIndex(Uint8List.fromList(v4.writeToBuffer())),
        throwsA(
          isA<UnsupportedResourceIndexError>()
              .having((e) => e.formatVersion, "formatVersion", 4)
              .having((e) => e.toString(), "message", contains("update the app")),
        ),
      );
    });
  });
}
