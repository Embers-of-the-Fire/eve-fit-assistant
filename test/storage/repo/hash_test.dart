import "dart:convert";
import "dart:typed_data";

import "package:eve_fit_assistant/storage/repo/hash.dart";
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

  group("hashResourceSnapshot", () {
    test("produces deterministic hash", () {
      final metaHash = "a" * 64;
      final pbHash = "b" * 64;
      final a = RepoHash.hashResourceSnapshot(metaHash, pbHash);
      final b = RepoHash.hashResourceSnapshot(metaHash, pbHash);
      expect(a, b);
      expect(a.length, 64);
    });

    test("different file hashes produce different snapshot hashes", () {
      final h1 = RepoHash.hashResourceSnapshot("a" * 64, "b" * 64);
      final h2 = RepoHash.hashResourceSnapshot("a" * 64, "c" * 64);
      expect(h1, isNot(h2));
    });

    test("hash is affected by metadata.json hash", () {
      final h1 = RepoHash.hashResourceSnapshot("a" * 64, "b" * 64);
      final h2 = RepoHash.hashResourceSnapshot("z" * 64, "b" * 64);
      expect(h1, isNot(h2));
    });
  });

  group("hashReleaseSnapshot", () {
    test("produces deterministic hash", () {
      final h1 = RepoHash.hashReleaseSnapshot("a" * 64, "b" * 64);
      final h2 = RepoHash.hashReleaseSnapshot("a" * 64, "b" * 64);
      expect(h1, h2);
    });

    test("domain separation from resource snapshot", () {
      final hResource = RepoHash.hashResourceSnapshot("a" * 64, "b" * 64);
      final hRelease = RepoHash.hashReleaseSnapshot("a" * 64, "b" * 64);
      expect(hResource, isNot(hRelease));
    });
  });

  group("hashAnnouncementSnapshot", () {
    test("produces deterministic hash", () {
      final h1 = RepoHash.hashAnnouncementSnapshot("a" * 64, "b" * 64);
      final h2 = RepoHash.hashAnnouncementSnapshot("a" * 64, "b" * 64);
      expect(h1, h2);
    });

    test("domain separation from other snapshots", () {
      final hResource = RepoHash.hashResourceSnapshot("a" * 64, "b" * 64);
      final hAnnounce = RepoHash.hashAnnouncementSnapshot("a" * 64, "b" * 64);
      expect(hResource, isNot(hAnnounce));
    });
  });

  group("hashGeneration", () {
    test("produces deterministic hash", () {
      final h1 = RepoHash.hashGeneration(
        metadataJsonHash: "a" * 64,
        serverPb2Hash: "b" * 64,
        resourcesPb2Hash: "c" * 64,
        releasesPb2Hash: "d" * 64,
        announcementsPb2Hash: "e" * 64,
      );
      final h2 = RepoHash.hashGeneration(
        metadataJsonHash: "a" * 64,
        serverPb2Hash: "b" * 64,
        resourcesPb2Hash: "c" * 64,
        releasesPb2Hash: "d" * 64,
        announcementsPb2Hash: "e" * 64,
      );
      expect(h1, h2);
    });

    test("any file change produces different hash", () {
      final base = RepoHash.hashGeneration(
        metadataJsonHash: "a" * 64,
        serverPb2Hash: "b" * 64,
        resourcesPb2Hash: "c" * 64,
        releasesPb2Hash: "d" * 64,
        announcementsPb2Hash: "e" * 64,
      );
      final changed = RepoHash.hashGeneration(
        metadataJsonHash: "z" * 64,
        serverPb2Hash: "b" * 64,
        resourcesPb2Hash: "c" * 64,
        releasesPb2Hash: "d" * 64,
        announcementsPb2Hash: "e" * 64,
      );
      expect(base, isNot(changed));
    });

    test("domain separation from snapshots", () {
      final hGen = RepoHash.hashGeneration(
        metadataJsonHash: "a" * 64,
        serverPb2Hash: "b" * 64,
        resourcesPb2Hash: "c" * 64,
        releasesPb2Hash: "d" * 64,
        announcementsPb2Hash: "e" * 64,
      );
      final hResource = RepoHash.hashResourceSnapshot("a" * 64, "b" * 64);
      expect(hGen, isNot(hResource));
    });
  });
}
