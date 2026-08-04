@TestOn("vm")
library;

import "dart:typed_data";

import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/storage/repo/resource_policy.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_test/flutter_test.dart";

ResourceIndex_Entry _entry([ResourceIndex_DownloadPolicy? policy]) {
  final entry = ResourceIndex_Entry()
    ..resourceId = "resource://static/images/icons/1.png"
    ..contentHash = "aa" * 32
    ..size = Int64(1);
  if (policy != null) entry.downloadPolicy = policy;
  return entry;
}

void main() {
  group("shouldEagerDownload", () {
    test("pre-policy indexes download every entry regardless of policy", () {
      final index = ResourceIndex()..schemaVersion = 1;

      expect(shouldEagerDownload(index, _entry()), isTrue);
      expect(shouldEagerDownload(index, _entry(ResourceIndex_DownloadPolicy.NON_FORCE)), isTrue);
      expect(shouldEagerDownload(index, _entry(ResourceIndex_DownloadPolicy.FORCE)), isTrue);
    });

    test("policy-aware indexes honor the entry policy", () {
      final index = ResourceIndex()
        ..schemaVersion = 1
        ..formatVersion = kPolicyAwareResourceIndexFormatVersion;

      expect(shouldEagerDownload(index, _entry(ResourceIndex_DownloadPolicy.FORCE)), isTrue);
      expect(shouldEagerDownload(index, _entry(ResourceIndex_DownloadPolicy.NON_FORCE)), isFalse);
    });

    test("absent policy in a policy-aware index defaults to lazy", () {
      final index = ResourceIndex()
        ..schemaVersion = 1
        ..formatVersion = kPolicyAwareResourceIndexFormatVersion;

      expect(shouldEagerDownload(index, _entry()), isFalse);
    });
  });

  group("decodeResourceIndex on native", () {
    test("accepts both pre-policy and policy-aware indexes", () {
      final v1 = ResourceIndex()..schemaVersion = 1;
      final v2 = ResourceIndex()
        ..schemaVersion = 1
        ..formatVersion = kPolicyAwareResourceIndexFormatVersion;

      expect(decodeResourceIndex(Uint8List.fromList(v1.writeToBuffer())).formatVersion, 1);
      expect(
        decodeResourceIndex(Uint8List.fromList(v2.writeToBuffer())).formatVersion,
        kPolicyAwareResourceIndexFormatVersion,
      );
    });
  });
}
