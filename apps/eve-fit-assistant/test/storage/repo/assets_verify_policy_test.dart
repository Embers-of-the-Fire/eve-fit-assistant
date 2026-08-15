@TestOn("vm")
library;

import "dart:typed_data";

import "package:eve_fit_assistant/config/paths.dart";
import "package:efa_proto/resource_index.pb.dart";
import "package:eve_fit_assistant/storage/fs/memory_blob_store.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_test/flutter_test.dart";

const _ridForce = "resource://static/collection.pb2";
const _ridLazy = "resource://static/images/graphics/1.png";

ResourceIndex_Entry _entry(String rid, String contentHash, {required bool force}) =>
    ResourceIndex_Entry()
      ..resourceId = rid
      ..contentHash = contentHash
      ..size = Int64(4)
      ..downloadPolicy = force
          ? ResourceIndex_DownloadPolicy.FORCE
          : ResourceIndex_DownloadPolicy.NON_FORCE;

void main() {
  late AssetStore assetStore;
  late Uint8List blobBytes;
  late String forceCH;
  late String lazyCH;

  setUp(() {
    PathProvider.appSupportPath = "/efa-test";
    assetStore = AssetStore.forTest(MemoryBlobStore());
    blobBytes = Uint8List.fromList([1, 2, 3, 4]);
    forceCH = RepoHash.hashContent(blobBytes);
    lazyCH = RepoHash.hashContent(Uint8List.fromList([9, 9, 9, 9]));
  });

  test("absent NON_FORCE blob is expected, absent FORCE blob is a failure", () async {
    final ri = ResourceIndex(
      schemaVersion: 1,
      formatVersion: 2,
      entries: [_entry(_ridForce, forceCH, force: true), _entry(_ridLazy, lazyCH, force: false)],
    );

    final failures = await assetStore.verifyResourceIndex(ri);

    expect(failures, contains(_ridForce));
    expect(failures, isNot(contains(_ridLazy)));
  });

  test("present NON_FORCE blob still hash-checks", () async {
    // Write different bytes under the lazy blob's content hash → mismatch.
    final identHash = RepoHash.hashIdent(_ridLazy);
    await assetStore.writeBlobUncheckedAt(
      RepoPaths.blobPath(identHash, lazyCH),
      Uint8List.fromList([0, 0, 0, 0]),
    );
    final ri = ResourceIndex(
      schemaVersion: 1,
      formatVersion: 2,
      entries: [_entry(_ridLazy, lazyCH, force: false)],
    );

    final failures = await assetStore.verifyResourceIndex(ri);

    expect(failures, contains(_ridLazy));
  });

  test("present clean NON_FORCE blob passes", () async {
    final lazyBytes = Uint8List.fromList([9, 9, 9, 9]);
    await assetStore.writeBlob(RepoHash.hashIdent(_ridLazy), lazyBytes);
    final ri = ResourceIndex(
      schemaVersion: 1,
      formatVersion: 2,
      entries: [_entry(_ridLazy, lazyCH, force: false)],
    );

    final failures = await assetStore.verifyResourceIndex(ri);

    expect(failures, isEmpty);
  });

  test("pre-policy indexes report every absent blob", () async {
    final ri = ResourceIndex(
      schemaVersion: 1,
      entries: [_entry(_ridLazy, lazyCH, force: false)],
    );

    final failures = await assetStore.verifyResourceIndex(ri);

    expect(failures, contains(_ridLazy));
  });
}
