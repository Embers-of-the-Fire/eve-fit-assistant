import "dart:io";
import "dart:typed_data";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/native_dir.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

void main() {
  const iconIdent = "resource://static/images/icons/123.png";
  final iconContent = Uint8List.fromList(List.generate(16, (i) => i));

  late Directory tempRoot;
  late String oldStorageRoot;
  late String newStorageRoot;
  late NativeDirResolver resolver;

  ResourceIndex writeIconBlob() {
    final written = const AssetStore().writeBlobSync(RepoHash.hashIdent(iconIdent), iconContent);
    return ResourceIndex(
      entries: [ResourceIndex_Entry(resourceId: iconIdent, contentHash: written.contentHash)],
    );
  }

  String iconPath(String nativeRoot) => p.join(nativeRoot, "static", "images", "icons", "123.png");

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp("efa_native_dir_test_");
    oldStorageRoot = p.join(tempRoot.path, "documents");
    newStorageRoot = p.join(tempRoot.path, "support");
    await Directory(oldStorageRoot).create(recursive: true);
    await Directory(newStorageRoot).create(recursive: true);
    PathProvider.appSupportPath = oldStorageRoot;
    PathProvider.tempPath = p.join(tempRoot.path, "temp");
    resolver = const NativeDirResolver(assetStore: AssetStore());
  });

  tearDown(() async {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test("materializes entries and records the blob root marker", () async {
    final index = writeIconBlob();

    final nativeRoot = await resolver.prepareNativeDir("snapshot_a", index);

    expect(await File(iconPath(nativeRoot)).readAsBytes(), iconContent);
    expect(File(p.join(nativeRoot, ".efa_blob_root")).readAsStringSync(), RepoPaths.assetsPath);
  });

  test("reuses a fresh native directory without rebuilding", () async {
    final index = writeIconBlob();
    final nativeRoot = await resolver.prepareNativeDir("snapshot_a", index);
    final sentinel = File(p.join(nativeRoot, "sentinel"));
    await sentinel.writeAsString("keep");

    final again = await resolver.prepareNativeDir("snapshot_a", index);

    expect(again, nativeRoot);
    expect(sentinel.existsSync(), isTrue, reason: "fresh native dir must not be rebuilt");
  });

  test("rebuilds when the blob root moved (documents -> support migration)", () async {
    final index = writeIconBlob();
    final nativeRoot = await resolver.prepareNativeDir("snapshot_a", index);

    // Simulate StoragePathMigrator: resources are renamed to the new root.
    await Directory(
      p.join(oldStorageRoot, "resources"),
    ).rename(p.join(newStorageRoot, "resources"));
    PathProvider.appSupportPath = newStorageRoot;

    expect(
      File(iconPath(nativeRoot)).existsSync(),
      isFalse,
      reason: "precondition: migration leaves dangling symlinks behind",
    );

    final rebuilt = await resolver.prepareNativeDir("snapshot_a", index);

    expect(rebuilt, nativeRoot);
    expect(await File(iconPath(rebuilt)).readAsBytes(), iconContent);
    expect(File(p.join(rebuilt, ".efa_blob_root")).readAsStringSync(), RepoPaths.assetsPath);
  });

  test("rebuilds when the marker is missing (install predating the fix)", () async {
    final index = writeIconBlob();
    final nativeRoot = await resolver.prepareNativeDir("snapshot_a", index);

    await Directory(
      p.join(oldStorageRoot, "resources"),
    ).rename(p.join(newStorageRoot, "resources"));
    PathProvider.appSupportPath = newStorageRoot;
    await File(p.join(nativeRoot, ".efa_blob_root")).delete();

    final rebuilt = await resolver.prepareNativeDir("snapshot_a", index);

    expect(await File(iconPath(rebuilt)).readAsBytes(), iconContent);
  });
}
