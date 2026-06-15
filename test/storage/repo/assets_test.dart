import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/models/asset_manifest.dart";
import "package:eve_fit_assistant/storage/repo/models/missing_files.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:path/path.dart" as p;

void main() {
  late String tempDir;
  late AssetStore assetStore;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_asset_test_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.tempPath = p.join(tempDir, "tmp");
    assetStore = const AssetStore();
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  AssetFile makeAssetFile(String path, List<int> content) {
    final pathHash = RepoHash.hashPath(path);
    final contentHash = RepoHash.hashContent(Uint8List.fromList(content));
    return AssetFile(pathHash: pathHash, hash: contentHash, size: content.length);
  }

  group("AssetStore.writeFileSync", () {
    test("writes file and returns correct hashes", () {
      final content = utf8.encode("Hello, world!") as Uint8List;
      final result = assetStore.writeFileSync("data/test.txt", content);

      expect(result.pathHash, hasLength(64));
      expect(result.contentHash, hasLength(64));
      expect(result.contentHash, RepoHash.hashContent(content));
      expect(result.pathHash, RepoHash.hashPath("data/test.txt"));
    });

    test("write-then-read round-trip for text content", () {
      final content = utf8.encode("Hello, asset store!") as Uint8List;
      final result = assetStore.writeFileSync("data/read-test.txt", content);

      final read = assetStore.readFileSync(result.pathHash, result.contentHash);

      expect(read.isSome(), isTrue);
      expect(read.toNullable(), content);
    });

    test("write-then-read round-trip for binary content", () {
      final content = Uint8List.fromList([0, 1, 2, 3, 255, 254, 253]);
      final result = assetStore.writeFileSync("data/binary.bin", content);

      final read = assetStore.readFileSync(result.pathHash, result.contentHash);

      expect(read.isSome(), isTrue);
      expect(read.toNullable(), content);
    });

    test("no partial files remain after write (atomicity)", () {
      final content = utf8.encode("atomic test") as Uint8List;
      final result = assetStore.writeFileSync("data/atomic.txt", content);

      final prefixDir = p.join(
        tempDir,
        "resources",
        "v2",
        "assets",
        result.pathHash.substring(0, 2),
      );

      final allFiles = Directory(prefixDir).listSync(recursive: true).whereType<File>().toList();
      expect(allFiles.length, 1);
      expect(p.basename(allFiles.first.path), result.contentHash);
      // No .tmp files lingering
      expect(allFiles.any((f) => f.path.endsWith(".tmp")), isFalse);
    });

    test("same content and same path produces single file (dedup)", () {
      final content = utf8.encode("dedup test") as Uint8List;
      final result1 = assetStore.writeFileSync("data/dedup.txt", content);
      final result2 = assetStore.writeFileSync("data/dedup.txt", content);

      expect(result1.pathHash, result2.pathHash);
      expect(result1.contentHash, result2.contentHash);
    });
  });

  group("AssetStore.readFileSync", () {
    test("returns None for non-existent file", () {
      final result = assetStore.readFileSync(
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      );
      expect(result.isNone(), isTrue);
    });
  });

  group("AssetStore.existsSync", () {
    test("returns true for existing file", () {
      final content = utf8.encode("exists test") as Uint8List;
      final result = assetStore.writeFileSync("data/exists.txt", content);

      expect(assetStore.existsSync(result.pathHash, result.contentHash), isTrue);
    });

    test("returns false for non-existent file", () {
      expect(
        assetStore.existsSync(
          "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        ),
        isFalse,
      );
    });
  });

  group("AssetStore.deleteFileSync", () {
    test("removes existing file", () {
      final content = utf8.encode("delete me") as Uint8List;
      final result = assetStore.writeFileSync("data/to-delete.txt", content);

      expect(assetStore.existsSync(result.pathHash, result.contentHash), isTrue);

      assetStore.deleteFileSync(result.pathHash, result.contentHash);

      expect(assetStore.existsSync(result.pathHash, result.contentHash), isFalse);
    });

    test("does not throw for non-existent file", () {
      assetStore.deleteFileSync(
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      );
    });
  });

  group("AssetStore.listContentHashes", () {
    test("returns empty list for non-existent path hash", () {
      final result = assetStore.listContentHashes(
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      );
      expect(result.isEmpty, isTrue);
    });

    test("returns all content hashes for a given path hash", () {
      final path = "data/multi-content.txt";
      final pathHash = RepoHash.hashPath(path);
      final content1 = utf8.encode("version 1") as Uint8List;
      final content2 = utf8.encode("version 2") as Uint8List;
      final content3 = utf8.encode("version 3") as Uint8List;

      final r1 = assetStore.writeFileSync(path, content1);
      final r2 = assetStore.writeFileSync(path, content2);
      final r3 = assetStore.writeFileSync(path, content3);

      expect(r1.pathHash, r2.pathHash);
      expect(r1.pathHash, r3.pathHash);

      final hashes = assetStore.listContentHashes(pathHash);
      expect(hashes.length, 3);
      expect(hashes, containsAll([r1.contentHash, r2.contentHash, r3.contentHash]));
    });

    test("returns only hashes under the specific path hash directory", () {
      final path1 = "data/one.txt";
      final path2 = "data/two.txt";
      final pathHash1 = RepoHash.hashPath(path1);
      final content1 = utf8.encode("one") as Uint8List;
      final content2 = utf8.encode("two") as Uint8List;

      assetStore.writeFileSync(path1, content1);
      assetStore.writeFileSync(path2, content2);

      final hashes1 = assetStore.listContentHashes(pathHash1);
      expect(hashes1.length, 1);
    });
  });

  group("AssetStore.verifyManifestSync", () {
    test("returns Right(unit) when all files are present and correct", () {
      final content1 = utf8.encode("file one") as Uint8List;
      final content2 = utf8.encode("file two") as Uint8List;
      final file1 = makeAssetFile("data/one.txt", content1);
      final file2 = makeAssetFile("data/two.txt", content2);

      assetStore.writeFileSync("data/one.txt", content1);
      assetStore.writeFileSync("data/two.txt", content2);

      final manifest = AssetManifest(
        assetsVersion: 1,
        files: IMap({file1.pathHash: file1, file2.pathHash: file2}),
      );

      final result = assetStore.verifyManifestSync(manifest);
      expect(result.isRight(), isTrue);
    });

    test("returns Left(MissingFiles) when a file is missing", () {
      final content = utf8.encode("present") as Uint8List;
      final file1 = makeAssetFile("data/present.txt", content);
      final file2 = makeAssetFile("data/missing.txt", utf8.encode("nope") as Uint8List);

      assetStore.writeFileSync("data/present.txt", content);

      final manifest = AssetManifest(
        assetsVersion: 1,
        files: IMap({file1.pathHash: file1, file2.pathHash: file2}),
      );

      final result = assetStore.verifyManifestSync(manifest);
      expect(result.isLeft(), isTrue);
      result.match((missing) {
        expect(missing.missing, contains(file2.pathHash));
        expect(missing.hashMismatches, isEmpty);
      }, (_) => fail("expected Left"));
    });

    test("returns Left(MissingFiles) when a file has hash mismatch", () {
      final correctContent = utf8.encode("correct") as Uint8List;
      final wrongContent = utf8.encode("wrong") as Uint8List;

      final pathHash = RepoHash.hashPath("data/correct.txt");
      final wrongHash = "0000000000000000000000000000000000000000000000000000000000000000";

      // Write wrong content at the asset path the manifest will reference
      final assetPath = RepoPaths.assetPath(pathHash, wrongHash);
      final file = File(assetPath);
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(wrongContent, flush: true);

      final manifestEntry = AssetFile(
        pathHash: pathHash,
        hash: wrongHash,
        size: wrongContent.length,
      );
      final manifest = AssetManifest(assetsVersion: 1, files: IMap({pathHash: manifestEntry}));

      final result = assetStore.verifyManifestSync(manifest);
      expect(result.isLeft(), isTrue);
      result.match((missing) {
        expect(missing.hashMismatches, contains(pathHash));
      }, (_) => fail("expected Left"));
    });
  });

  group("AssetStore.pruneSync", () {
    test("removes unreferenced files, keeps referenced ones", () {
      final referencedContent = utf8.encode("keep me") as Uint8List;
      final unreferencedContent = utf8.encode("remove me") as Uint8List;

      final refFile = makeAssetFile("data/keep.txt", referencedContent);
      final unrefFile = makeAssetFile("data/remove.txt", unreferencedContent);

      assetStore.writeFileSync("data/keep.txt", referencedContent);
      assetStore.writeFileSync("data/remove.txt", unreferencedContent);

      // Verify both exist
      expect(assetStore.existsSync(refFile.pathHash, refFile.hash), isTrue);
      expect(assetStore.existsSync(unrefFile.pathHash, unrefFile.hash), isTrue);

      final activeManifest = AssetManifest(
        assetsVersion: 1,
        files: IMap({refFile.pathHash: refFile}),
      );

      assetStore.pruneSync(IList([activeManifest]));

      // Referenced file still exists
      expect(assetStore.existsSync(refFile.pathHash, refFile.hash), isTrue);
      // Unreferenced file removed
      expect(assetStore.existsSync(unrefFile.pathHash, unrefFile.hash), isFalse);
    });

    test("handles empty active manifests (removes all)", () {
      final content = utf8.encode("all gone") as Uint8List;
      final file = makeAssetFile("data/gone.txt", content);

      assetStore.writeFileSync("data/gone.txt", content);
      expect(assetStore.existsSync(file.pathHash, file.hash), isTrue);

      assetStore.pruneSync(IList());

      expect(assetStore.existsSync(file.pathHash, file.hash), isFalse);
    });

    test("handles empty assets directory gracefully", () {
      assetStore.pruneSync(IList());
    });

    test("handles multiple active manifests (union)", () {
      final content1 = utf8.encode("manifest one") as Uint8List;
      final content2 = utf8.encode("manifest two") as Uint8List;
      final content3 = utf8.encode("orphan") as Uint8List;

      final file1 = makeAssetFile("data/m1.txt", content1);
      final file2 = makeAssetFile("data/m2.txt", content2);
      final file3 = makeAssetFile("data/orphan.txt", content3);

      assetStore.writeFileSync("data/m1.txt", content1);
      assetStore.writeFileSync("data/m2.txt", content2);
      assetStore.writeFileSync("data/orphan.txt", content3);

      final manifest1 = AssetManifest(assetsVersion: 1, files: IMap({file1.pathHash: file1}));
      final manifest2 = AssetManifest(assetsVersion: 1, files: IMap({file2.pathHash: file2}));

      assetStore.pruneSync(IList([manifest1, manifest2]));

      expect(assetStore.existsSync(file1.pathHash, file1.hash), isTrue);
      expect(assetStore.existsSync(file2.pathHash, file2.hash), isTrue);
      expect(assetStore.existsSync(file3.pathHash, file3.hash), isFalse);
    });

    test("removes empty pathHash directories after pruning", () {
      final content = utf8.encode("temporary") as Uint8List;
      final file = makeAssetFile("data/temp.txt", content);

      assetStore.writeFileSync("data/temp.txt", content);
      expect(assetStore.existsSync(file.pathHash, file.hash), isTrue);

      // Verify the pathHash directory exists
      final pathHashDir = Directory(
        p.join(
          PathProvider.documentsPath,
          "resources",
          "v2",
          "assets",
          file.pathHash.substring(0, 2),
          file.pathHash,
        ),
      );
      expect(pathHashDir.existsSync(), isTrue);

      // Prune with no active manifests (everything deleted)
      assetStore.pruneSync(IList());

      expect(assetStore.existsSync(file.pathHash, file.hash), isFalse);
      // Empty pathHash directory should be removed
      expect(pathHashDir.existsSync(), isFalse);
    });

    test("pruneSync is idempotent (calling twice does not error)", () {
      final content = utf8.encode("idempotent test") as Uint8List;
      final file = makeAssetFile("data/idempotent.txt", content);

      assetStore.writeFileSync("data/idempotent.txt", content);

      // Prune with no manifests
      assetStore.pruneSync(IList());
      // Second call should not throw
      expect(() => assetStore.pruneSync(IList()), returnsNormally);
    });
  });
}
