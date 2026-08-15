import "dart:typed_data";

import "package:efa_compat/io.dart" show Directory;
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:efa_proto/resource_index.pb.dart";
import "package:eve_fit_assistant/storage/fs/memory_blob_store.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/on_demand_blob.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:mocktail/mocktail.dart";

class MockRemoteCatalogService extends Mock implements RemoteCatalogService {}

const _rid = "resource://static/images/graphics/1.png";

void main() {
  late AssetStore assetStore;
  late MockRemoteCatalogService mockRemote;
  late OnDemandBlobFetcher fetcher;
  late String identHash;
  late String contentHash;
  late Uint8List blobBytes;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    if (!kIsWeb) {
      final logDir = Directory.systemTemp.createTempSync("efa_on_demand_blob_test_log_");
      GlobalLogger.init(logDir.path, enableDebugLog: false);
    }
  });

  setUp(() {
    // RepoPaths derives blob paths from PathProvider; the in-memory store only
    // uses them as keys, so a placeholder root is enough.
    PathProvider.appSupportPath = "/efa-test";

    assetStore = AssetStore.forTest(MemoryBlobStore());
    mockRemote = MockRemoteCatalogService();
    fetcher = OnDemandBlobFetcher(assetStore: assetStore, remoteCatalog: mockRemote);

    blobBytes = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);
    contentHash = RepoHash.hashContent(blobBytes);
    identHash = RepoHash.hashIdent(_rid);

    when(() => mockRemote.fetchBlob(any(), any())).thenAnswer((_) async => Right(blobBytes));
  });

  group("OnDemandBlobFetcher", () {
    test("serves a locally present blob without fetching", () async {
      await assetStore.writeBlob(identHash, blobBytes);

      final result = await fetcher.read(identHash, contentHash);

      expect(result.toNullable(), blobBytes);
      verifyNever(() => mockRemote.fetchBlob(any(), any()));
    });

    test("downloads an absent blob, stores it, and serves the bytes", () async {
      final result = await fetcher.read(identHash, contentHash);

      expect(result.toNullable(), blobBytes);
      verify(() => mockRemote.fetchBlob(identHash, contentHash)).called(1);
      expect(await assetStore.blobExists(identHash, contentHash), isTrue);

      // Second read hits the store, not the network.
      final again = await fetcher.read(identHash, contentHash);
      expect(again.toNullable(), blobBytes);
      verifyNever(() => mockRemote.fetchBlob(any(), any()));
    });

    test("returns None when the remote fetch fails", () async {
      when(
        () => mockRemote.fetchBlob(any(), any()),
      ).thenAnswer((_) async => const Left(CatalogNetworkError(message: "offline")));

      final result = await fetcher.read(identHash, contentHash);

      expect(result.isNone(), isTrue);
      expect(await assetStore.blobExists(identHash, contentHash), isFalse);
    });

    test("rejects a corrupt payload whose content hash does not match", () async {
      final corrupt = Uint8List.fromList([0x00, 0x11, 0x22]);
      when(() => mockRemote.fetchBlob(any(), any())).thenAnswer((_) async => Right(corrupt));

      final result = await fetcher.read(identHash, contentHash);

      expect(result.isNone(), isTrue);
      expect(await assetStore.blobExists(identHash, contentHash), isFalse);
    });

    test("deduplicates concurrent reads of the same blob", () async {
      final results = await Future.wait([
        fetcher.read(identHash, contentHash),
        fetcher.read(identHash, contentHash),
        fetcher.read(identHash, contentHash),
      ]);

      for (final r in results) {
        expect(r.toNullable(), blobBytes);
      }
      verify(() => mockRemote.fetchBlob(identHash, contentHash)).called(1);
    });
  });

  group("ResourceBlobProxy read-through", () {
    ResourceIndex buildIndex() => ResourceIndex(
      schemaVersion: 1,
      formatVersion: 2,
      entries: [
        ResourceIndex_Entry(
          resourceId: _rid,
          contentHash: contentHash,
          size: Int64(4),
          downloadPolicy: ResourceIndex_DownloadPolicy.NON_FORCE,
        ),
      ],
    );

    test("fetches a missing blob through the fetcher", () async {
      final proxy = ResourceBlobProxy(assetStore, buildIndex(), fetcher);

      final bytes = await proxy.read(_rid);

      expect(bytes.toNullable(), blobBytes);
      verify(() => mockRemote.fetchBlob(identHash, contentHash)).called(1);
      expect(await assetStore.blobExists(identHash, contentHash), isTrue);
    });

    test("returns None for a missing blob without a fetcher", () async {
      final proxy = ResourceBlobProxy(assetStore, buildIndex());

      final bytes = await proxy.read(_rid);

      expect(bytes.isNone(), isTrue);
      verifyNever(() => mockRemote.fetchBlob(any(), any()));
    });

    test("reads a present blob locally without the fetcher", () async {
      await assetStore.writeBlob(identHash, blobBytes);
      final proxy = ResourceBlobProxy(assetStore, buildIndex(), fetcher);

      final bytes = await proxy.read(_rid);

      expect(bytes.toNullable(), blobBytes);
      verifyNever(() => mockRemote.fetchBlob(any(), any()));
    });
  });
}
