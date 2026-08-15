@TestOn("browser")
library;

import "dart:typed_data";

import "package:eve_fit_assistant/config/paths.dart";
import "package:efa_proto/resource_index.pb.dart";
import "package:eve_fit_assistant/storage/fs/opfs_blob_store.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_test/flutter_test.dart";

/// Prune coverage against the real OPFS backend: the native prune suites use
/// `dart:io` `File` and cannot run on web, leaving the web prune path
/// (checkout switch making a new checkout's blobs active) untested.
void main() {
  late OpfsBlobStore opfs;
  late AssetStore assetStore;

  setUpAll(() async {
    await PathProvider.init();
  });

  setUp(() async {
    opfs = OpfsBlobStore.forTest();
    await opfs.init();
    assetStore = AssetStore.forTest(opfs);
  });

  tearDown(() async {
    await opfs.deleteTree(RepoPaths.assetsPath);
  });

  test("prune preserves the active checkout's snapshot and blobs over OPFS", () async {
    const rid = "resource://test/web_keep.bin";
    final blobBytes = Uint8List.fromList([1, 2, 3]);
    final ihash = RepoHash.hashIdent(rid);
    final chash = RepoHash.hashContent(blobBytes);

    final ri = ResourceIndex()
      ..schemaVersion = 1
      ..entries.add(
        ResourceIndex_Entry()
          ..resourceId = rid
          ..contentHash = chash
          ..size = Int64(blobBytes.length),
      );

    const activeHash = "snap-active-web";
    await opfs.write(RepoPaths.resourceIndexPath(activeHash), Uint8List.fromList([0]));
    await opfs.write(RepoPaths.blobPath(ihash, chash), blobBytes);

    final orphanBlobPath = RepoPaths.blobPath(ihash, "ff" * 32);
    final orphanSnapshotPath = RepoPaths.resourceIndexPath("snap-orphan-web");
    await opfs.write(orphanBlobPath, blobBytes);
    await opfs.write(orphanSnapshotPath, Uint8List.fromList([0]));

    final deleted = await assetStore.prune(
      activeSnapshotHashes: {activeHash},
      activeResourceIndexes: [ri],
    );

    expect(deleted, 2);
    expect(await opfs.exists(RepoPaths.resourceIndexPath(activeHash)), isTrue);
    expect(await opfs.exists(RepoPaths.blobPath(ihash, chash)), isTrue);
    expect(await opfs.exists(orphanBlobPath), isFalse);
    expect(await opfs.exists(orphanSnapshotPath), isFalse);
  });
}
