import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/models/asset_manifest.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:eve_fit_assistant/storage/repo/native_dir.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

void main() {
  late String tempDir;
  late AssetStore assetStore;
  late NativeDirResolver resolver;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_native_dir_test_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.tempPath = p.join(tempDir, "tmp");
    assetStore = const AssetStore();
    resolver = NativeDirResolver(assetStore: assetStore);
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group("NativeDirResolver.prepareNativeDir", () {
    test("returns path to directory containing assets at original paths", () async {
      final content1 = utf8.encode("alpha content");
      final content2 = utf8.encode("beta content");

      assetStore.writeFileSync("data/alpha.pb", content1);
      assetStore.writeFileSync("nested/beta.pb", content2);

      final pathHash1 = RepoHash.hashPath("data/alpha.pb");
      final contentHash1 = RepoHash.hashContent(content1);
      final pathHash2 = RepoHash.hashPath("nested/beta.pb");
      final contentHash2 = RepoHash.hashContent(content2);

      final manifest = AssetManifest(
        assetsVersion: 1,
        files: IMap({
          "data/alpha.pb": AssetFile(
            pathHash: pathHash1,
            hash: contentHash1,
            size: content1.length,
          ),
          "nested/beta.pb": AssetFile(
            pathHash: pathHash2,
            hash: contentHash2,
            size: content2.length,
          ),
        }),
      );

      final nativeRoot = await resolver.prepareNativeDir(manifest);

      final alphaFile = File(p.join(nativeRoot, "data", "alpha.pb"));
      final betaFile = File(p.join(nativeRoot, "nested", "beta.pb"));

      expect(alphaFile.existsSync(), isTrue);
      expect(betaFile.existsSync(), isTrue);
      expect(alphaFile.readAsBytesSync(), content1);
      expect(betaFile.readAsBytesSync(), content2);
    });

    test("reuses existing directory on second call with same manifest", () async {
      final content = utf8.encode("reuse test");
      assetStore.writeFileSync("test.pb", content);

      final pathHash = RepoHash.hashPath("test.pb");
      final contentHash = RepoHash.hashContent(content);

      final manifest = AssetManifest(
        assetsVersion: 1,
        files: IMap({
          "test.pb": AssetFile(pathHash: pathHash, hash: contentHash, size: content.length),
        }),
      );

      final firstPath = await resolver.prepareNativeDir(manifest);
      final secondPath = await resolver.prepareNativeDir(manifest);

      expect(secondPath, firstPath);
      expect(Directory(firstPath).existsSync(), isTrue);
    });

    test("different manifests produce different directories", () async {
      final content1 = utf8.encode("first");
      final content2 = utf8.encode("second");

      assetStore.writeFileSync("a.pb", content1);
      assetStore.writeFileSync("b.pb", content2);

      final manifest1 = AssetManifest(
        assetsVersion: 1,
        files: IMap({
          "a.pb": AssetFile(
            pathHash: RepoHash.hashPath("a.pb"),
            hash: RepoHash.hashContent(content1),
            size: content1.length,
          ),
        }),
      );

      final manifest2 = AssetManifest(
        assetsVersion: 1,
        files: IMap({
          "b.pb": AssetFile(
            pathHash: RepoHash.hashPath("b.pb"),
            hash: RepoHash.hashContent(content2),
            size: content2.length,
          ),
        }),
      );

      final path1 = await resolver.prepareNativeDir(manifest1);
      final path2 = await resolver.prepareNativeDir(manifest2);

      expect(path1, isNot(path2));
    });

    test("empty manifest returns directory with no files", () async {
      final manifest = AssetManifest(assetsVersion: 1);

      final nativeRoot = await resolver.prepareNativeDir(manifest);

      expect(Directory(nativeRoot).existsSync(), isTrue);
      expect(Directory(nativeRoot).listSync(), isEmpty);
    });
  });

  group("NativeDirResolver.cleanup", () {
    test("removes stale native directories not referenced by active manifests", () async {
      final content = utf8.encode("keep");
      assetStore.writeFileSync("keep.pb", content);

      final pathHash = RepoHash.hashPath("keep.pb");
      final contentHash = RepoHash.hashContent(content);

      final activeManifest = AssetManifest(
        assetsVersion: 1,
        files: IMap({
          "keep.pb": AssetFile(pathHash: pathHash, hash: contentHash, size: content.length),
        }),
      );

      final activePath = await resolver.prepareNativeDir(activeManifest);

      // Create a stale directory manually that would not match any active manifest
      final nativeBase = p.join(PathProvider.tempPath, "efa", "native");
      final staleDir = Directory(
        p.join(nativeBase, "deadbeefdeadbeefstalehashnotreal000000000000"),
      );
      staleDir.createSync(recursive: true);
      File(p.join(staleDir.path, "stale.txt")).writeAsStringSync("stale");

      expect(staleDir.existsSync(), isTrue);
      expect(Directory(activePath).existsSync(), isTrue);

      resolver.cleanup([activeManifest]);

      expect(staleDir.existsSync(), isFalse);
      expect(Directory(activePath).existsSync(), isTrue);
    });

    test("no active manifests removes all native directories", () async {
      final content = utf8.encode("gone");
      assetStore.writeFileSync("gone.pb", content);

      final manifest = AssetManifest(
        assetsVersion: 1,
        files: IMap({
          "gone.pb": AssetFile(
            pathHash: RepoHash.hashPath("gone.pb"),
            hash: RepoHash.hashContent(content),
            size: content.length,
          ),
        }),
      );

      final nativePath = await resolver.prepareNativeDir(manifest);
      expect(Directory(nativePath).existsSync(), isTrue);

      resolver.cleanup([]);

      expect(Directory(nativePath).existsSync(), isFalse);
    });

    test("handles missing native base directory gracefully", () {
      // Delete the base directory if it exists
      final nativeBase = p.join(PathProvider.tempPath, "efa", "native");
      final baseDir = Directory(nativeBase);
      if (baseDir.existsSync()) baseDir.deleteSync(recursive: true);

      // Should not throw
      resolver.cleanup([]);
    });

    test("multiple active manifests keeps all referenced directories", () async {
      final content1 = utf8.encode("first");
      final content2 = utf8.encode("second");

      assetStore.writeFileSync("a.pb", content1);
      assetStore.writeFileSync("b.pb", content2);

      final manifest1 = AssetManifest(
        assetsVersion: 1,
        files: IMap({
          "a.pb": AssetFile(
            pathHash: RepoHash.hashPath("a.pb"),
            hash: RepoHash.hashContent(content1),
            size: content1.length,
          ),
        }),
      );

      final manifest2 = AssetManifest(
        assetsVersion: 1,
        files: IMap({
          "b.pb": AssetFile(
            pathHash: RepoHash.hashPath("b.pb"),
            hash: RepoHash.hashContent(content2),
            size: content2.length,
          ),
        }),
      );

      final path1 = await resolver.prepareNativeDir(manifest1);
      final path2 = await resolver.prepareNativeDir(manifest2);

      expect(Directory(path1).existsSync(), isTrue);
      expect(Directory(path2).existsSync(), isTrue);

      resolver.cleanup([manifest1, manifest2]);

      expect(Directory(path1).existsSync(), isTrue);
      expect(Directory(path2).existsSync(), isTrue);
    });
  });
}
