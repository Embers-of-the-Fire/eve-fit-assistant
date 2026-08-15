@TestOn("vm")
library;

import "dart:typed_data";

import "package:efa_compat/io.dart" show Directory;
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/storage/fs/memory_blob_store.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/provisioning.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_test/flutter_test.dart";

typedef _EntrySpec = ({
  String resourceId,
  String contentHash,
  int size,
  ResourceIndex_DownloadPolicy? policy,
});

ResourceIndex _index({required int formatVersion, required List<_EntrySpec> entries}) {
  final ri = ResourceIndex()
    ..schemaVersion = 1
    ..formatVersion = formatVersion;
  for (final e in entries) {
    final entry = ResourceIndex_Entry()
      ..resourceId = e.resourceId
      ..contentHash = e.contentHash
      ..size = Int64(e.size);
    final policy = e.policy;
    if (policy != null) entry.downloadPolicy = policy;
    ri.entries.add(entry);
  }
  return ri;
}

const _v2 = 2;

void main() {
  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_provisioning_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  setUp(() {
    // RepoPaths derives blob paths from PathProvider; the in-memory store only
    // uses them as keys, so a placeholder root is enough.
    PathProvider.appSupportPath = "/efa-test";
  });

  late AssetStore assetStore;

  setUp(() {
    assetStore = AssetStore.forTest(MemoryBlobStore());
  });

  group("computeEagerWorkList", () {
    test("pre-policy indexes treat every entry as eager", () async {
      final index = _index(
        formatVersion: 1,
        entries: [
          (
            resourceId: "resource://static/collection.pb2",
            contentHash: "aa" * 32,
            size: 10,
            policy: ResourceIndex_DownloadPolicy.NON_FORCE,
          ),
          (
            resourceId: "resource://static/images/icons/1.png",
            contentHash: "bb" * 32,
            size: 20,
            policy: null,
          ),
        ],
      );

      final workList = await computeEagerWorkList(assetStore, [index]);

      expect(workList.totalEntries, 2);
      expect(workList.totalBytes, 30);
      expect(workList.toDownload, hasLength(2));
      expect(workList.cachedCount, 0);
    });

    test("policy-aware indexes skip NON_FORCE entries", () async {
      final index = _index(
        formatVersion: _v2,
        entries: [
          (
            resourceId: "resource://static/collection.pb2",
            contentHash: "aa" * 32,
            size: 10,
            policy: ResourceIndex_DownloadPolicy.FORCE,
          ),
          (
            resourceId: "resource://static/images/icons/1.png",
            contentHash: "bb" * 32,
            size: 20,
            policy: ResourceIndex_DownloadPolicy.NON_FORCE,
          ),
          // Absent policy defaults to NON_FORCE in the policy-aware format.
          (
            resourceId: "resource://static/images/icons/2.png",
            contentHash: "cc" * 32,
            size: 30,
            policy: null,
          ),
        ],
      );

      final workList = await computeEagerWorkList(assetStore, [index]);

      expect(workList.totalEntries, 1);
      expect(workList.totalBytes, 10);
      expect(workList.toDownload, hasLength(1));
      expect(workList.toDownload.single.entry.resourceId, "resource://static/collection.pb2");
    });

    test("dedups identical blobs across indexes", () async {
      final shared = (
        resourceId: "resource://static/collection.pb2",
        contentHash: "aa" * 32,
        size: 10,
        policy: ResourceIndex_DownloadPolicy.FORCE,
      );
      final indexA = _index(formatVersion: _v2, entries: [shared]);
      final indexB = _index(formatVersion: _v2, entries: [shared]);

      final workList = await computeEagerWorkList(assetStore, [indexA, indexB]);

      expect(workList.totalEntries, 1);
      expect(workList.toDownload, hasLength(1));
    });

    test("distinct resources sharing content are both provisioned", () async {
      // Blob identity is (identHash, contentHash): two resource ids with
      // identical content live at different store paths.
      final index = _index(
        formatVersion: _v2,
        entries: [
          (
            resourceId: "resource://static/images/icons/1.png",
            contentHash: "aa" * 32,
            size: 10,
            policy: ResourceIndex_DownloadPolicy.FORCE,
          ),
          (
            resourceId: "resource://static/images/icons/2.png",
            contentHash: "aa" * 32,
            size: 10,
            policy: ResourceIndex_DownloadPolicy.FORCE,
          ),
        ],
      );

      final workList = await computeEagerWorkList(assetStore, [index]);

      expect(workList.totalEntries, 2);
      expect(workList.toDownload, hasLength(2));
    });

    test("counts blobs already in the store as cached", () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final contentHash = RepoHash.hashContent(bytes);
      final identHash = RepoHash.hashIdent("resource://static/collection.pb2");
      await assetStore.writeBlob(identHash, bytes);

      final index = _index(
        formatVersion: _v2,
        entries: [
          (
            resourceId: "resource://static/collection.pb2",
            contentHash: contentHash,
            size: bytes.length,
            policy: ResourceIndex_DownloadPolicy.FORCE,
          ),
          (
            resourceId: "resource://localization/localization.db",
            contentHash: "dd" * 32,
            size: 7,
            policy: ResourceIndex_DownloadPolicy.FORCE,
          ),
        ],
      );

      final workList = await computeEagerWorkList(assetStore, [index]);

      expect(workList.totalEntries, 2);
      expect(workList.cachedCount, 1);
      expect(workList.cachedBytes, bytes.length);
      expect(workList.toDownload, hasLength(1));
      expect(
        workList.toDownload.single.entry.resourceId,
        "resource://localization/localization.db",
      );
    });

    test("sorts toDownload largest-first", () async {
      final index = _index(
        formatVersion: _v2,
        entries: [
          (
            resourceId: "resource://a",
            contentHash: "aa" * 32,
            size: 5,
            policy: ResourceIndex_DownloadPolicy.FORCE,
          ),
          (
            resourceId: "resource://b",
            contentHash: "bb" * 32,
            size: 100,
            policy: ResourceIndex_DownloadPolicy.FORCE,
          ),
          (
            resourceId: "resource://c",
            contentHash: "cc" * 32,
            size: 42,
            policy: ResourceIndex_DownloadPolicy.FORCE,
          ),
        ],
      );

      final workList = await computeEagerWorkList(assetStore, [index]);

      expect(workList.toDownload.map((b) => b.size).toList(), [100, 42, 5]);
    });

    test("precomputes ident hash and blob path", () async {
      const resourceId = "resource://static/collection.pb2";
      final contentHash = "aa" * 32;
      final index = _index(
        formatVersion: _v2,
        entries: [
          (
            resourceId: resourceId,
            contentHash: contentHash,
            size: 1,
            policy: ResourceIndex_DownloadPolicy.FORCE,
          ),
        ],
      );

      final workList = await computeEagerWorkList(assetStore, [index]);
      final blob = workList.toDownload.single;

      expect(blob.identHash, RepoHash.hashIdent(resourceId));
      expect(blob.blobPath, contains(blob.identHash));
      expect(blob.blobPath, contains(contentHash));
    });
  });
}
