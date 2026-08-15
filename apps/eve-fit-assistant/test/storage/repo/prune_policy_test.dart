import "dart:typed_data";

import "package:eve_fit_assistant/config/paths.dart";
import "package:efa_proto/resource_index.pb.dart";
import "package:eve_fit_assistant/storage/fs/memory_blob_store.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_test/flutter_test.dart";

/// Store-agnostic prune policy coverage: referenced-hash computation and
/// prune decisions are exercised against [MemoryBlobStore] so they run on
/// every platform (the filesystem-backed suites are VM-only).
void main() {
  const rid = "resource://test/keep.bin";
  final blobBytes = Uint8List.fromList([1, 2, 3]);
  final ihash = RepoHash.hashIdent(rid);
  final chash = RepoHash.hashContent(blobBytes);

  ResourceIndex buildIndex() => ResourceIndex()
    ..schemaVersion = 1
    ..entries.add(
      ResourceIndex_Entry()
        ..resourceId = rid
        ..contentHash = chash
        ..size = Int64(blobBytes.length),
    );

  setUp(() {
    PathProvider.documentsPath = "/efa_prune_policy_test";
    PathProvider.appSupportPath = "/efa_prune_policy_test";
    PathProvider.tempPath = "/efa_prune_policy_test";
    PathProvider.cachesPath = "/efa_prune_policy_test";
    PathProvider.downloadsPath = null;
  });

  test("referencedBlobPaths covers every entry of the given indexes", () {
    final referenced = referencedBlobPaths([buildIndex()]);

    expect(referenced, {normalizeStorePath(RepoPaths.blobPath(ihash, chash))});
  });

  test("referencedBlobPaths normalizes separators", () {
    final referenced = referencedBlobPaths([buildIndex()]);

    expect(referenced.every((path) => !path.contains(r"\")), isTrue);
  });

  test("prune keeps referenced data and deletes the rest", () async {
    final store = MemoryBlobStore();
    final assetStore = AssetStore.forTest(store);

    const activeHash = "snap-active";
    await store.write(RepoPaths.resourceIndexPath(activeHash), Uint8List.fromList([0]));
    await store.write(RepoPaths.resourceSnapshotMetaPath(activeHash), Uint8List.fromList([0]));
    await store.write(RepoPaths.blobPath(ihash, chash), blobBytes);

    // Unreferenced: another content version of the same ident, an orphan
    // snapshot, and an interrupted-write leftover.
    final orphanBlobPath = RepoPaths.blobPath(ihash, "ff" * 32);
    final orphanSnapshotPath = RepoPaths.resourceIndexPath("snap-orphan");
    final tmpPath = "${RepoPaths.blobPath(ihash, "ee" * 32)}.tmp";
    await store.write(orphanBlobPath, blobBytes);
    await store.write(orphanSnapshotPath, Uint8List.fromList([0]));
    await store.write(tmpPath, blobBytes);

    final deleted = await assetStore.prune(
      activeSnapshotHashes: {activeHash},
      activeResourceIndexes: [buildIndex()],
    );

    expect(deleted, 3);
    expect(await store.exists(RepoPaths.resourceIndexPath(activeHash)), isTrue);
    expect(await store.exists(RepoPaths.resourceSnapshotMetaPath(activeHash)), isTrue);
    expect(await store.exists(RepoPaths.blobPath(ihash, chash)), isTrue);
    expect(await store.exists(orphanBlobPath), isFalse);
    expect(await store.exists(orphanSnapshotPath), isFalse);
    expect(await store.exists(tmpPath), isFalse);
  });
}
