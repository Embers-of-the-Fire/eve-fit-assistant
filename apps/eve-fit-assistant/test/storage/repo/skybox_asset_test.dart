@TestOn("vm")
library;

import "dart:typed_data";

import "package:efa_compat/io.dart" show Directory;
import "package:efa_proto/resource_index.pb.dart";
import "package:efa_proto/skybox.pb.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/fs/memory_blob_store.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:eve_fit_assistant/storage/repo/skybox_asset.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter_test/flutter_test.dart";

SkyboxMetadata _sidecar({int schemaVersion = 1, int shFloats = 27}) {
  final meta = SkyboxMetadata()
    ..schemaVersion = schemaVersion
    ..id = "a01"
    ..family = "universe"
    ..nebulaIntensity = 1.25;
  if (shFloats > 0) meta.diffuseSh.addAll(List.filled(shFloats, 0.5));
  return meta;
}

void main() {
  late AssetStore assetStore;

  setUpAll(() {
    if (!kIsWeb) {
      final logDir = Directory.systemTemp.createTempSync("efa_skybox_asset_test_log_");
      GlobalLogger.init(logDir.path, enableDebugLog: false);
    }
  });

  setUp(() {
    // RepoPaths derives blob paths from PathProvider; the in-memory store only
    // uses them as keys, so a placeholder root is enough.
    PathProvider.appSupportPath = "/efa-test";
    assetStore = AssetStore.forTest(MemoryBlobStore());
  });

  /// An index-only proxy (no stored blobs; `read` resolves to [None]).
  ResourceBlobProxy proxyWith(List<String> resourceIds) {
    final index = ResourceIndex()
      ..schemaVersion = 1
      ..entries.addAll([
        for (final rid in resourceIds)
          ResourceIndex_Entry(resourceId: rid, contentHash: "00", size: Int64(1)),
      ]);
    return ResourceBlobProxy(assetStore, index);
  }

  /// Stores [blobs] (`resource id → bytes`) and returns a proxy whose index
  /// addresses them with their real content hashes.
  Future<ResourceBlobProxy> proxyWithBlobs(Map<String, Uint8List> blobs) async {
    final entries = <ResourceIndex_Entry>[];
    for (final MapEntry(key: rid, value: bytes) in blobs.entries) {
      final hashes = await assetStore.writeBlob(RepoHash.hashIdent(rid), bytes);
      entries.add(
        ResourceIndex_Entry(
          resourceId: rid,
          contentHash: hashes.contentHash,
          size: Int64(bytes.length),
        ),
      );
    }
    final index = ResourceIndex()
      ..schemaVersion = 1
      ..entries.addAll(entries);
    return ResourceBlobProxy(assetStore, index);
  }

  group("listSkyboxes", () {
    test("enumerates .hdr entries with ids and families, sorted", () {
      final service = SkyboxAssetService(
        proxyWith([
          "resource://static/skyboxes/wormhole_class_01.hdr",
          "resource://static/skyboxes/ad01_a.hdr",
          "resource://static/skyboxes/c02.hdr",
          "resource://static/skyboxes/a01.hdr",
          "resource://static/skyboxes/a01.pb2",
          "resource://static/models/ships/587.full.glb",
        ]),
      );
      final catalog = service.listSkyboxes();
      expect(catalog.map((s) => s.id), ["a01", "ad01_a", "c02", "wormhole_class_01"]);
      expect(catalog.map((s) => s.family), ["universe", "abyssal", "universe", "wormholes"]);
    });

    test("is empty when the index ships no skyboxes", () {
      expect(SkyboxAssetService(proxyWith(const [])).listSkyboxes(), isEmpty);
    });
  });

  group("hasSkybox", () {
    test("keys on the .hdr blob alone (a missing sidecar degrades)", () {
      final service = SkyboxAssetService(proxyWith(const ["resource://static/skyboxes/a01.hdr"]));
      expect(service.hasSkybox("a01"), isTrue);
      expect(service.hasSkybox("c02"), isFalse);
    });
  });

  group("readSkybox", () {
    test("returns None when the .hdr blob is not in the index", () async {
      final service = SkyboxAssetService(proxyWith(const []));
      expect((await service.readSkybox("a01")).isNone(), isTrue);
    });

    test("returns the hdr bytes with a parsed sidecar", () async {
      final hdrBytes = Uint8List.fromList([1, 2, 3]);
      final proxy = await proxyWithBlobs({
        "resource://static/skyboxes/a01.hdr": hdrBytes,
        "resource://static/skyboxes/a01.pb2": Uint8List.fromList(_sidecar().writeToBuffer()),
      });
      final asset = (await SkyboxAssetService(proxy).readSkybox("a01")).toNullable();
      expect(asset, isNotNull);
      expect(asset!.hdrBytes, hdrBytes);
      expect(asset.metadata, isNotNull);
      expect(asset.metadata!.id, "a01");
      expect(asset.metadata!.nebulaIntensity, closeTo(1.25, 1e-6));
      expect(asset.metadata!.diffuseSh, hasLength(27));
    });

    test("a missing sidecar degrades to metadata: null", () async {
      final proxy = await proxyWithBlobs({
        "resource://static/skyboxes/a01.hdr": Uint8List.fromList([1, 2, 3]),
      });
      final asset = (await SkyboxAssetService(proxy).readSkybox("a01")).toNullable();
      expect(asset, isNotNull);
      expect(asset!.metadata, isNull);
    });

    test("an unsupported sidecar schema_version degrades to metadata: null", () async {
      final proxy = await proxyWithBlobs({
        "resource://static/skyboxes/a01.hdr": Uint8List.fromList([1, 2, 3]),
        "resource://static/skyboxes/a01.pb2": Uint8List.fromList(
          _sidecar(schemaVersion: 2).writeToBuffer(),
        ),
      });
      final asset = (await SkyboxAssetService(proxy).readSkybox("a01")).toNullable();
      expect(asset!.metadata, isNull);
    });

    test("a malformed diffuse_sh (not 27 floats) degrades to metadata: null", () async {
      final proxy = await proxyWithBlobs({
        "resource://static/skyboxes/a01.hdr": Uint8List.fromList([1, 2, 3]),
        "resource://static/skyboxes/a01.pb2": Uint8List.fromList(
          _sidecar(shFloats: 3).writeToBuffer(),
        ),
      });
      final asset = (await SkyboxAssetService(proxy).readSkybox("a01")).toNullable();
      expect(asset!.metadata, isNull);
    });

    test("an undecodable sidecar degrades to metadata: null", () async {
      final proxy = await proxyWithBlobs({
        "resource://static/skyboxes/a01.hdr": Uint8List.fromList([1, 2, 3]),
        "resource://static/skyboxes/a01.pb2": Uint8List.fromList([0xFF, 0xFF, 0xFF]),
      });
      final asset = (await SkyboxAssetService(proxy).readSkybox("a01")).toNullable();
      expect(asset!.metadata, isNull);
    });
  });
}
