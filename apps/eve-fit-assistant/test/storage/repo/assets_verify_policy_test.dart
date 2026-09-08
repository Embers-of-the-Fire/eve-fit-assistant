@TestOn("vm")
library;

import "dart:typed_data";

import "package:eve_fit_assistant/config/paths.dart";
import "package:efa_proto/resource_index.pb.dart";
import "package:eve_fit_assistant/storage/fs/memory_blob_store.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/resource_resolution.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_test/flutter_test.dart";

const _ridEager = "resource://static/collection.pb2";
const _ridLazy = "resource://static/images/graphics/1.png";
const _ridExcluded = "resource://localization/localization.db";
const _ridLocale = "resource://localization/locales/en.db";

/// The RRS evaluation context used by these tests.
const _ctx = ResourceResolutionContext(locale: "en");

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
  late String eagerCH;
  late String lazyCH;

  setUp(() {
    PathProvider.appSupportPath = "/efa-test";
    assetStore = AssetStore.forTest(MemoryBlobStore());
    blobBytes = Uint8List.fromList([1, 2, 3, 4]);
    eagerCH = RepoHash.hashContent(blobBytes);
    lazyCH = RepoHash.hashContent(Uint8List.fromList([9, 9, 9, 9]));
  });

  test("absent lazy blob is expected, absent eager blob is a failure", () async {
    final ri = ResourceIndex(
      schemaVersion: 1,
      formatVersion: 2,
      entries: [_entry(_ridEager, eagerCH, force: true), _entry(_ridLazy, lazyCH, force: false)],
    );

    final failures = await assetStore.verifyResourceIndex(ri, context: _ctx);

    expect(failures, contains(_ridEager));
    expect(failures, isNot(contains(_ridLazy)));
  });

  test("present lazy blob still hash-checks", () async {
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

    final failures = await assetStore.verifyResourceIndex(ri, context: _ctx);

    expect(failures, contains(_ridLazy));
  });

  test("present clean lazy blob passes", () async {
    final lazyBytes = Uint8List.fromList([9, 9, 9, 9]);
    await assetStore.writeBlob(RepoHash.hashIdent(_ridLazy), lazyBytes);
    final ri = ResourceIndex(
      schemaVersion: 1,
      formatVersion: 2,
      entries: [_entry(_ridLazy, lazyCH, force: false)],
    );

    final failures = await assetStore.verifyResourceIndex(ri, context: _ctx);

    expect(failures, isEmpty);
  });

  test("pre-policy indexes resolve entries via the RRS", () async {
    // The resolution replaces the stamped policy: the collection is eager
    // (R5 default) and reported when absent; the image is lazy (R4) even
    // though pre-policy indexes carry no download policy.
    final ri = ResourceIndex(
      schemaVersion: 1,
      entries: [_entry(_ridEager, eagerCH, force: false), _entry(_ridLazy, lazyCH, force: false)],
    );

    final failures = await assetStore.verifyResourceIndex(ri, context: _ctx);

    expect(failures, contains(_ridEager));
    expect(failures, isNot(contains(_ridLazy)));
  });

  test("excluded entries are ignored entirely, even when absent", () async {
    // With per-locale dbs present, R1 excludes the legacy combined db: its
    // blob is neither checked nor counted, so a missing excluded blob never
    // becomes a repair loop.
    final ri = ResourceIndex(
      schemaVersion: 1,
      formatVersion: 2,
      entries: [
        _entry(_ridExcluded, "dd" * 32, force: true),
        _entry(_ridLocale, "ee" * 32, force: false),
      ],
    );

    var reportedTotal = -1;
    final failures = await assetStore.verifyResourceIndex(
      ri,
      context: _ctx,
      onProgress: (_, total) => reportedTotal = total,
    );

    // The legacy db is excluded (ignored); the active locale's db is eager
    // and absent → failure. The excluded entry does not count toward totals.
    expect(failures, contains(_ridLocale));
    expect(failures, isNot(contains(_ridExcluded)));
    expect(reportedTotal, 1);
  });
}
