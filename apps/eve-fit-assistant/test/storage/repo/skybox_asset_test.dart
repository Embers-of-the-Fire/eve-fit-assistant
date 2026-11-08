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
import "package:eve_fit_assistant/storage/repo/lighting_profile.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:eve_fit_assistant/storage/repo/skybox_asset.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter_test/flutter_test.dart";

SceneLightingProfile _lightingProfile(
  String id, {
  LightingProfileKind kind = LightingProfileKind.ITEM_PREVIEW,
  String? skyboxId,
  String reflectionResource = "res:/dx9/scene/preview/refl_cube_refl.dds",
  double nebula = 1,
  double reflection = 1,
  double ambientR = 0.25,
  double ambientG = 0.25,
  double ambientB = 0.25,
  double sun = 3,
  SunDirectionMode directionMode = SunDirectionMode.CAMERA_FORWARD,
  List<double>? fixedDirection,
}) {
  final profile = SceneLightingProfile()
    ..id = id
    ..kind = kind
    ..skyboxId = skyboxId ?? (kind == LightingProfileKind.FITTING ? "fitting" : "m10")
    ..reflectionResource = reflectionResource
    ..nebulaIntensity = nebula
    ..reflectionIntensity = reflection
    ..ambientColor = RgbColor(r: ambientR, g: ambientG, b: ambientB)
    ..sunColor = RgbColor(r: sun, g: sun, b: sun)
    ..sunDirectionMode = directionMode;
  if (fixedDirection != null) {
    profile.fixedSunDirection = Vector3(
      x: fixedDirection[0],
      y: fixedDirection[1],
      z: fixedDirection[2],
    );
  }
  return profile;
}

LightingProfileCatalog _lightingCatalog(
  Iterable<SceneLightingProfile> profiles, {
  int schemaVersion = 1,
}) => LightingProfileCatalog()
  ..schemaVersion = schemaVersion
  ..profiles.addAll(profiles);

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
          "resource://static/skyboxes/fitting.hdr",
          "resource://static/skyboxes/previewturrets.hdr",
          "resource://static/skyboxes/a01.pb2",
          "resource://static/skyboxes/lighting_profiles.pb2",
          "resource://static/models/ships/587.full.glb",
        ]),
      );
      final catalog = service.listSkyboxes();
      expect(catalog.map((s) => s.id), [
        "a01",
        "ad01_a",
        "c02",
        "fitting",
        "previewturrets",
        "wormhole_class_01",
      ]);
      expect(catalog.map((s) => s.family), [
        "universe",
        "abyssal",
        "universe",
        "fitting",
        "fitting",
        "wormholes",
      ]);
      expect(catalog.any((skybox) => skybox.id == "lighting_profiles"), isFalse);
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

  group("skyboxAssetIdentity", () {
    test("is null when the .hdr blob is absent from the index", () {
      final service = SkyboxAssetService(proxyWith(const []));
      expect(service.skyboxAssetIdentity("a01"), isNull);
    });

    test("combines the HDR and sidecar content hashes", () async {
      final sidecar = Uint8List.fromList(_sidecar().writeToBuffer());
      final withSidecar = await proxyWithBlobs({
        "resource://static/skyboxes/a01.hdr": Uint8List.fromList([1, 2, 3]),
        "resource://static/skyboxes/a01.pb2": sidecar,
      });
      final withoutSidecar = await proxyWithBlobs({
        "resource://static/skyboxes/a01.hdr": Uint8List.fromList([1, 2, 3]),
      });
      final changedHdr = await proxyWithBlobs({
        "resource://static/skyboxes/a01.hdr": Uint8List.fromList([4, 5, 6]),
        "resource://static/skyboxes/a01.pb2": sidecar,
      });

      final identity = SkyboxAssetService(withSidecar).skyboxAssetIdentity("a01");
      expect(identity, isNotNull);
      // A missing sidecar is part of the identity: the runtime SH path
      // produces a different environment than a precomputed sidecar.
      expect(
        SkyboxAssetService(withoutSidecar).skyboxAssetIdentity("a01"),
        isNot(equals(identity)),
      );
      expect(SkyboxAssetService(changedHdr).skyboxAssetIdentity("a01"), isNot(equals(identity)));
      expect(SkyboxAssetService(withSidecar).skyboxAssetIdentity("c02"), isNull);
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

    test("non-finite diffuse_sh degrades to metadata: null", () async {
      final metadata = _sidecar();
      metadata.diffuseSh[8] = double.nan;
      final proxy = await proxyWithBlobs({
        "resource://static/skyboxes/a01.hdr": Uint8List.fromList([1, 2, 3]),
        "resource://static/skyboxes/a01.pb2": Uint8List.fromList(metadata.writeToBuffer()),
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

  group("readLightingProfiles", () {
    Future<SkyboxAssetService> serviceForCatalog(LightingProfileCatalog catalog) async {
      final proxy = await proxyWithBlobs({
        SkyboxAssetService.lightingProfileCatalogResourceId: Uint8List.fromList(
          catalog.writeToBuffer(),
        ),
      });
      return SkyboxAssetService(proxy);
    }

    test("parses fully resolved item-preview and fitting profiles", () async {
      final fittingDirection = [-0.53916383, -0.53916383, 0.64699662];
      final service = await serviceForCatalog(
        _lightingCatalog([
          _lightingProfile(
            "amarr",
            skyboxId: "a05",
            reflectionResource: "res:/dx9/scene/preview/amarr_cube_refl.dds",
          ),
          _lightingProfile(
            "fitting",
            kind: LightingProfileKind.FITTING,
            skyboxId: "fitting",
            ambientR: 0.30408299,
            ambientG: 0.45882350,
            ambientB: 0.45336211,
            sun: 2,
            directionMode: SunDirectionMode.FIXED,
            fixedDirection: fittingDirection,
          ),
        ]),
      );
      final profiles = await service.readLightingProfiles();
      expect(profiles, isNotNull);
      expect(profiles!.keys, unorderedEquals(["amarr", "fitting"]));
      final amarr = profiles["amarr"]!;
      expect(amarr.kind, AppLightingProfileKind.itemPreview);
      expect(amarr.skyboxId, "a05");
      expect(amarr.reflectionResource, "res:/dx9/scene/preview/amarr_cube_refl.dds");
      expect(amarr.keyIntensity, 3);
      expect(amarr.sunDirectionMode, AppSunDirectionMode.cameraForward);
      expect(amarr.fixedSunDirection, isNull);
      final fitting = profiles["fitting"]!;
      expect(fitting.kind, AppLightingProfileKind.fitting);
      expect(fitting.keyIntensity, 2);
      expect(fitting.ambientColor.g, closeTo(0.45882350, 1e-6));
      expect(fitting.fixedSunDirection!.length, closeTo(1, 1e-6));
      expect(fitting.fixedSunDirection!.z, greaterThan(0));
    });

    test("memoizes the in-flight and completed catalog load", () async {
      final service = await serviceForCatalog(_lightingCatalog([_lightingProfile("generic")]));
      final first = service.readLightingProfiles();
      final second = service.readLightingProfiles();
      expect(identical(first, second), isTrue);
      final firstValue = await first;
      final secondValue = await second;
      expect(identical(firstValue, secondValue), isTrue);
      expect(identical(service.readLightingProfiles(), first), isTrue);
    });

    test("an absent catalog has null compatibility semantics and is memoized", () async {
      final service = SkyboxAssetService(proxyWith(const []));
      final first = service.readLightingProfiles();
      expect(identical(service.readLightingProfiles(), first), isTrue);
      expect(await first, isNull);
    });

    test("an undecodable catalog has null compatibility semantics", () async {
      final proxy = await proxyWithBlobs({
        SkyboxAssetService.lightingProfileCatalogResourceId: Uint8List.fromList([0xFF, 0xFF, 0xFF]),
      });
      expect(await SkyboxAssetService(proxy).readLightingProfiles(), isNull);
    });

    test("an unsupported catalog version has null compatibility semantics", () async {
      final service = await serviceForCatalog(
        _lightingCatalog([_lightingProfile("generic")], schemaVersion: 2),
      );
      expect(await service.readLightingProfiles(), isNull);
    });

    test("invalid scalar, RGB, and direction profiles are omitted", () async {
      final invalid = [
        _lightingProfile("negative_nebula", nebula: -1),
        _lightingProfile("nan_nebula", nebula: double.nan),
        _lightingProfile("zero_reflection", reflection: 0),
        _lightingProfile("infinite_reflection", reflection: double.infinity),
        _lightingProfile("negative_ambient", ambientR: -0.1),
        _lightingProfile("nan_ambient", ambientG: double.nan),
        _lightingProfile("zero_key", sun: 0),
        _lightingProfile(
          "fixed_zero",
          directionMode: SunDirectionMode.FIXED,
          fixedDirection: [0, 0, 0],
        ),
        _lightingProfile("camera_with_fixed", fixedDirection: [0, 0, 1]),
        _lightingProfile("fitting_camera", kind: LightingProfileKind.FITTING),
      ];
      final service = await serviceForCatalog(
        _lightingCatalog([_lightingProfile("generic"), ...invalid]),
      );
      final profiles = await service.readLightingProfiles();
      expect(profiles!.keys, ["generic"]);
    });

    test("non-neutral key products and missing reflection provenance are invalid", () {
      final colored = _lightingProfile("colored");
      colored.sunColor.g = 2;
      expect(AppLightingProfile.tryFromProto(colored), isNull);
      final noReflection = _lightingProfile("no_reflection")..clearReflectionResource();
      expect(AppLightingProfile.tryFromProto(noReflection), isNull);
      final missingColorChannel = _lightingProfile("missing_color_channel");
      missingColorChannel.ambientColor.clearG();
      expect(AppLightingProfile.tryFromProto(missingColorChannel), isNull);
      final missingVectorComponent = _lightingProfile(
        "missing_vector_component",
        kind: LightingProfileKind.FITTING,
        directionMode: SunDirectionMode.FIXED,
        fixedDirection: [0, 0, 1],
      );
      missingVectorComponent.fixedSunDirection.clearZ();
      expect(AppLightingProfile.tryFromProto(missingVectorComponent), isNull);
    });

    test("duplicate raw ids are rejected even when one occurrence is invalid", () async {
      final service = await serviceForCatalog(
        _lightingCatalog([
          _lightingProfile("generic"),
          _lightingProfile("amarr", skyboxId: "a05"),
          _lightingProfile("amarr", skyboxId: "a05", reflection: 0),
        ]),
      );
      final profiles = await service.readLightingProfiles();
      expect(profiles!.keys, ["generic"]);
      expect(profiles.containsKey("amarr"), isFalse);
    });

    test("two valid occurrences of one id are equally ambiguous and rejected", () async {
      final service = await serviceForCatalog(
        _lightingCatalog([
          _lightingProfile("generic"),
          _lightingProfile("amarr", skyboxId: "a05"),
          _lightingProfile("amarr", skyboxId: "a10"),
        ]),
      );
      expect((await service.readLightingProfiles())!.keys, ["generic"]);
    });
  });
}
