import "dart:typed_data";

import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/utils/canonical_json.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("RepoHash primitives", () {
    test("hashBytes returns 64 hex chars", () {
      final hash = RepoHash.hashBytes(Uint8List.fromList([1, 2, 3]));
      expect(hash.length, 64);
      expect(hash, isNot(contains(" ")));
    });

    test("hashString is deterministic", () {
      final a = RepoHash.hashString("hello");
      final b = RepoHash.hashString("hello");
      expect(a, b);
    });

    test("hashContent matches hashBytes", () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      expect(RepoHash.hashContent(bytes), RepoHash.hashBytes(bytes));
    });
  });

  group("hashIdent", () {
    test("produces 64 hex chars", () {
      final ident = RepoHash.hashIdent("resource://tranquility/proto/ships.bin");
      expect(ident.length, 64);
    });

    test("different URIs produce different hashes", () {
      final a = RepoHash.hashIdent("resource://tranquility/a");
      final b = RepoHash.hashIdent("resource://tranquility/b");
      expect(a, isNot(b));
    });
  });

  group("hashResourceSnapshot (v3)", () {
    test("produces deterministic hash", () {
      final metaHash = "a" * 64;
      final a = RepoHash.hashResourceSnapshot(metaHash);
      final b = RepoHash.hashResourceSnapshot(metaHash);
      expect(a, b);
      expect(a.length, 64);
    });

    test("different metadata hashes produce different snapshot hashes", () {
      final h1 = RepoHash.hashResourceSnapshot("a" * 64);
      final h2 = RepoHash.hashResourceSnapshot("b" * 64);
      expect(h1, isNot(h2));
    });

    test("produces expected hash for known input", () {
      // Cross-platform: must match Python canonicaljson output for {"schemaVersion":1}
      final metaBytes = canonicalJsonEncode({"schemaVersion": 1});
      final metaHash = RepoHash.hashContent(metaBytes);
      final snapshotHash = RepoHash.hashResourceSnapshot(metaHash);
      expect(snapshotHash, "6eb189b14800ba95c7b26afad39c81d9efc639257a39c1afb9bf5fc62ee06a4c");
    });
  });

  group("hashReleaseSnapshot (v3)", () {
    test("produces deterministic hash", () {
      final h1 = RepoHash.hashReleaseSnapshot("a" * 64);
      final h2 = RepoHash.hashReleaseSnapshot("a" * 64);
      expect(h1, h2);
    });

    test("domain separation from resource snapshot", () {
      final hResource = RepoHash.hashResourceSnapshot("a" * 64);
      final hRelease = RepoHash.hashReleaseSnapshot("a" * 64);
      expect(hResource, isNot(hRelease));
    });
  });

  group("hashGeneration (v3)", () {
    test("produces deterministic hash", () {
      final h1 = RepoHash.hashGeneration(metadataJsonHash: "a" * 64);
      final h2 = RepoHash.hashGeneration(metadataJsonHash: "a" * 64);
      expect(h1, h2);
    });

    test("metadata change produces different hash", () {
      final base = RepoHash.hashGeneration(metadataJsonHash: "a" * 64);
      final changed = RepoHash.hashGeneration(metadataJsonHash: "z" * 64);
      expect(base, isNot(changed));
    });

    test("domain separation from snapshots", () {
      final hGen = RepoHash.hashGeneration(metadataJsonHash: "a" * 64);
      final hResource = RepoHash.hashResourceSnapshot("a" * 64);
      expect(hGen, isNot(hResource));
    });

    test("produces expected hash for known input", () {
      final metaBytes = canonicalJsonEncode({"schemaVersion": 1});
      final metaHash = RepoHash.hashContent(metaBytes);
      final genHash = RepoHash.hashGeneration(metadataJsonHash: metaHash);
      expect(genHash, "ef7c9ac6cc8c3c2ab2583af5027a4b1fd11c4aaca4e029a5293710b07e0e78dd");
    });
  });

  group("hashResourceSnapshotV4", () {
    test("produces deterministic hash", () {
      final a = RepoHash.hashResourceSnapshotV4(
        metadataJsonHash: "a" * 64,
        resourcesPb2Hash: "b" * 64,
      );
      final b = RepoHash.hashResourceSnapshotV4(
        metadataJsonHash: "a" * 64,
        resourcesPb2Hash: "b" * 64,
      );
      expect(a, b);
      expect(a.length, 64);
    });

    test("binds the resources.pb2 index (tamper sensitivity)", () {
      final base = RepoHash.hashResourceSnapshotV4(
        metadataJsonHash: "a" * 64,
        resourcesPb2Hash: "b" * 64,
      );
      final tampered = RepoHash.hashResourceSnapshotV4(
        metadataJsonHash: "a" * 64,
        resourcesPb2Hash: "c" * 64,
      );
      expect(base, isNot(tampered));
    });

    test("differs from v3 (which ignores the index)", () {
      final v3 = RepoHash.hashResourceSnapshot("a" * 64);
      final v4 = RepoHash.hashResourceSnapshotV4(
        metadataJsonHash: "a" * 64,
        resourcesPb2Hash: "b" * 64,
      );
      expect(v3, isNot(v4));
    });

    test("Python parity for known component hashes", () {
      // Must match bootstrap/tests/test_verify.py::test_known_value_parity.
      final h = RepoHash.hashResourceSnapshotV4(
        metadataJsonHash: "a" * 64,
        resourcesPb2Hash: "b" * 64,
      );
      expect(h, "a76dfbcd80a9457f09b32241c7a9b239de581d1db784786279e59b90a3891c69");
    });
  });

  group("hashReleaseSnapshotV4", () {
    test("Python parity for known component hashes", () {
      final h = RepoHash.hashReleaseSnapshotV4(
        metadataJsonHash: "a" * 64,
        releasesPb2Hash: "b" * 64,
      );
      expect(h, "8e3558913730e810d6bcf65fe1ae9b6a859f4166976cc69e94dc60953ee665cd");
    });

    test("domain separation from resource snapshot v4", () {
      final res = RepoHash.hashResourceSnapshotV4(
        metadataJsonHash: "a" * 64,
        resourcesPb2Hash: "b" * 64,
      );
      final rel = RepoHash.hashReleaseSnapshotV4(
        metadataJsonHash: "a" * 64,
        releasesPb2Hash: "b" * 64,
      );
      expect(res, isNot(rel));
    });
  });
}
