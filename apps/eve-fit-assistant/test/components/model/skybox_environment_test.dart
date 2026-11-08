@TestOn("vm")
library;

import "dart:async";
import "dart:typed_data";

import "package:efa_proto/resource_index.pb.dart";
import "package:efa_proto/skybox.pb.dart" as pb;
import "package:efa_proto/types.pb.dart" as pb_types;
import "package:eve_fit_assistant/components/model/skybox_environment.dart";
import "package:eve_fit_assistant/storage/fs/memory_blob_store.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/lighting_profile.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:eve_fit_assistant/storage/repo/skybox_asset.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_scene/scene.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vector_math/vector_math.dart" as vm;

AppLightingProfile _profile(
  String id,
  String skyboxId, {
  AppLightingProfileKind kind = AppLightingProfileKind.itemPreview,
  double nebula = 1,
  double reflection = 1,
  vm.Vector3? ambient,
  double key = 3,
  AppSunDirectionMode directionMode = AppSunDirectionMode.cameraForward,
  vm.Vector3? fixedDirection,
}) => AppLightingProfile(
  id: id,
  kind: kind,
  skyboxId: skyboxId,
  reflectionResource: "res:/dx9/scene/$id.refl",
  nebulaIntensity: nebula,
  reflectionIntensity: reflection,
  ambientColor: ambient ?? vm.Vector3.all(0.25),
  sunColor: vm.Vector3.all(key),
  sunDirectionMode: directionMode,
  fixedSunDirection: fixedDirection,
);

Map<String, AppLightingProfile> _profiles(Iterable<AppLightingProfile> profiles) => {
  for (final profile in profiles) profile.id: profile,
};

void _expectVector(vm.Vector3 actual, vm.Vector3 expected, {double epsilon = 1e-6}) {
  expect(actual.x, closeTo(expected.x, epsilon));
  expect(actual.y, closeTo(expected.y, epsilon));
  expect(actual.z, closeTo(expected.z, epsilon));
}

void main() {
  SkyboxAssetService serviceWithCatalog(List<String> skyboxIds) {
    final index = ResourceIndex()
      ..schemaVersion = 1
      ..entries.addAll([
        for (final id in skyboxIds)
          ResourceIndex_Entry(
            resourceId: "resource://static/skyboxes/$id.hdr",
            contentHash: "00",
            size: Int64(1),
          ),
      ]);
    return SkyboxAssetService(ResourceBlobProxy(AssetStore.forTest(MemoryBlobStore()), index));
  }

  List<int>? noFactions(int factionId) => null;

  group("profile and environment selection", () {
    final service = serviceWithCatalog([
      "a05",
      "a10",
      "c01",
      "c02",
      "c05",
      "c06",
      "c07",
      "c18",
      "fitting",
      "g04",
      "g06",
      "m01",
      "m10",
      "ad01_a",
      "wormhole_class_01",
    ]);
    final generic = _profile("generic", "m10");
    final amarr = _profile("amarr", "a05");
    final fitting = _profile(
      "fitting",
      "fitting",
      kind: AppLightingProfileKind.fitting,
      key: 2,
      directionMode: AppSunDirectionMode.fixed,
      fixedDirection: vm.Vector3(-0.53916383, -0.53916383, 0.64699662).normalized(),
    );
    final catalog = _profiles([generic, amarr, fitting]);
    final amarrType = pb_types.Type()..raceId = 4;

    test("auto Amarr resolves environment a05 and profile amarr", () {
      final active = resolveLightingProfile(
        mode: ShipModelLightingMode.itemPreview,
        profiles: catalog,
        type: amarrType,
        factionMemberRaces: noFactions,
      );
      expect(active, same(amarr));
      expect(
        resolveEnvironmentId(
          setting: kShipModelSkyboxAuto,
          mode: ShipModelLightingMode.itemPreview,
          activeProfile: active,
          service: service,
          type: amarrType,
          factionMemberRaces: noFactions,
        ),
        "a05",
      );
    });

    test("manual c01 changes only the environment, retaining amarr lighting", () {
      final active = resolveLightingProfile(
        mode: ShipModelLightingMode.itemPreview,
        profiles: catalog,
        type: amarrType,
        factionMemberRaces: noFactions,
      );
      expect(active, same(amarr));
      expect(
        resolveEnvironmentId(
          setting: "c01",
          mode: ShipModelLightingMode.itemPreview,
          activeProfile: active,
          service: service,
          type: amarrType,
          factionMemberRaces: noFactions,
        ),
        "c01",
      );
    });

    test(
      "fitting auto resolves fitting profile/environment; manual environment is only an override",
      () {
        final active = resolveLightingProfile(
          mode: ShipModelLightingMode.fitting,
          profiles: catalog,
          type: amarrType,
          factionMemberRaces: noFactions,
        );
        expect(active, same(fitting));
        expect(
          resolveEnvironmentId(
            setting: kShipModelSkyboxAuto,
            mode: ShipModelLightingMode.fitting,
            activeProfile: active,
            service: service,
            type: amarrType,
            factionMemberRaces: noFactions,
          ),
          "fitting",
        );
        expect(
          resolveEnvironmentId(
            setting: "c01",
            mode: ShipModelLightingMode.fitting,
            activeProfile: active,
            service: service,
            type: amarrType,
            factionMemberRaces: noFactions,
          ),
          "c01",
        );
        expect(active.sunDirectionMode, AppSunDirectionMode.fixed);
      },
    );

    test("manual fitting skybox in item-preview mode keeps camera-forward amarr lighting", () {
      final active = resolveLightingProfile(
        mode: ShipModelLightingMode.itemPreview,
        profiles: catalog,
        type: amarrType,
        factionMemberRaces: noFactions,
      );
      expect(active, same(amarr));
      expect(active.sunDirectionMode, AppSunDirectionMode.cameraForward);
      expect(
        resolveEnvironmentId(
          setting: "fitting",
          mode: ShipModelLightingMode.itemPreview,
          activeProfile: active,
          service: service,
          type: amarrType,
          factionMemberRaces: noFactions,
        ),
        "fitting",
      );
    });

    test("unknown race and faction resolve catalog generic", () {
      final type = pb_types.Type()
        ..raceId = 128
        ..factionId = 999999;
      expect(
        resolveLightingProfile(
          mode: ShipModelLightingMode.itemPreview,
          profiles: catalog,
          type: type,
          factionMemberRaces: noFactions,
        ),
        same(generic),
      );
    });

    test("dedicated faction profiles win over member and type races", () {
      final sansha = _profile("sansha", "a10");
      final profiles = _profiles([generic, sansha]);
      final type = pb_types.Type()
        ..raceId = 2
        ..factionId = 500019;
      expect(
        resolveLightingProfile(
          mode: ShipModelLightingMode.itemPreview,
          profiles: profiles,
          type: type,
          factionMemberRaces: (_) => [1],
        ),
        same(sansha),
      );
    });

    test("an unlisted faction follows its first member race before the type race", () {
      final caldari = _profile("caldari", "c05");
      final profiles = _profiles([generic, caldari]);
      final type = pb_types.Type()
        ..raceId = 2
        ..factionId = 500010;
      expect(
        resolveLightingProfile(
          mode: ShipModelLightingMode.itemPreview,
          profiles: profiles,
          type: type,
          factionMemberRaces: (_) => [1, 4],
        ),
        same(caldari),
      );
    });

    test("a missing selected profile falls back to catalog generic", () {
      expect(
        resolveLightingProfile(
          mode: ShipModelLightingMode.itemPreview,
          profiles: _profiles([generic]),
          type: amarrType,
          factionMemberRaces: noFactions,
        ),
        same(generic),
      );
    });

    test("missing catalog generic uses only the built-in generic compatibility profile", () {
      final active = resolveLightingProfile(
        mode: ShipModelLightingMode.itemPreview,
        profiles: const {},
        type: amarrType,
        factionMemberRaces: noFactions,
      );
      expect(active, same(kGenericItemPreviewLightingProfile));
      expect(active.skyboxId, "m10");
      expect(active.keyIntensity, 3);
      expect(active.sunDirectionMode, AppSunDirectionMode.cameraForward);
    });

    test("an unavailable catalog uses built-in generic regardless of ship race", () {
      expect(
        resolveLightingProfile(
          mode: ShipModelLightingMode.itemPreview,
          profiles: null,
          type: amarrType,
          factionMemberRaces: noFactions,
        ),
        same(kGenericItemPreviewLightingProfile),
      );
    });

    test("an unavailable catalog uses built-in fitting with authored values", () {
      final active = resolveLightingProfile(
        mode: ShipModelLightingMode.fitting,
        profiles: null,
        type: amarrType,
        factionMemberRaces: noFactions,
      );
      expect(active, same(kFittingLightingProfile));
      expect(active.skyboxId, "fitting");
      expect(active.keyIntensity, 2);
      _expectVector(active.ambientColor, vm.Vector3(0.30408299, 0.45882350, 0.45336211));
      expect(active.fixedSunDirection!.length, closeTo(1, 1e-6));
      expect(active.fixedSunDirection!.z, greaterThan(0));
    });

    test("a valid catalog missing fitting uses catalog generic, not built-in fitting", () {
      expect(
        resolveLightingProfile(
          mode: ShipModelLightingMode.fitting,
          profiles: _profiles([generic]),
          type: amarrType,
          factionMemberRaces: noFactions,
        ),
        same(generic),
      );
      expect(
        resolveLightingProfile(
          mode: ShipModelLightingMode.fitting,
          profiles: const {},
          type: amarrType,
          factionMemberRaces: noFactions,
        ),
        same(kGenericItemPreviewLightingProfile),
      );
    });

    test(
      "a missing concrete environment id behaves as auto without changing selection semantics",
      () {
        expect(
          resolveEnvironmentId(
            setting: "removed_skybox",
            mode: ShipModelLightingMode.itemPreview,
            activeProfile: amarr,
            service: service,
            type: amarrType,
            factionMemberRaces: noFactions,
          ),
          "a05",
        );
      },
    );

    test("a missing profile environment follows race/faction environment fallbacks then m10", () {
      final missing = _profile("amarr", "missing_a05");
      expect(
        resolveEnvironmentId(
          setting: kShipModelSkyboxAuto,
          mode: ShipModelLightingMode.itemPreview,
          activeProfile: missing,
          service: service,
          type: amarrType,
          factionMemberRaces: noFactions,
        ),
        "a05",
      );
      expect(
        resolveEnvironmentId(
          setting: kShipModelSkyboxAuto,
          mode: ShipModelLightingMode.itemPreview,
          activeProfile: generic,
          service: serviceWithCatalog(["c05"]),
          type: pb_types.Type()..raceId = 1,
          factionMemberRaces: noFactions,
        ),
        "c05",
      );
    });

    test("fitting auto falls back to m10, never to item-preview lighting", () {
      final active = resolveLightingProfile(
        mode: ShipModelLightingMode.fitting,
        profiles: catalog,
        type: amarrType,
        factionMemberRaces: noFactions,
      );
      expect(
        resolveEnvironmentId(
          setting: kShipModelSkyboxAuto,
          mode: ShipModelLightingMode.fitting,
          activeProfile: active,
          service: serviceWithCatalog(["m10", "a05"]),
          type: amarrType,
          factionMemberRaces: noFactions,
        ),
        "m10",
      );
      expect(active.kind, AppLightingProfileKind.fitting);
    });

    test("no environment resolves only when all applicable catalog fallbacks are absent", () {
      expect(
        resolveEnvironmentId(
          setting: kShipModelSkyboxAuto,
          mode: ShipModelLightingMode.itemPreview,
          activeProfile: generic,
          service: serviceWithCatalog(["a01"]),
          type: pb_types.Type()..raceId = 128,
          factionMemberRaces: noFactions,
        ),
        isNull,
      );
      expect(
        resolveEnvironmentId(
          setting: kShipModelSkyboxAuto,
          mode: ShipModelLightingMode.fitting,
          activeProfile: fitting,
          service: serviceWithCatalog(["a05"]),
          type: amarrType,
          factionMemberRaces: noFactions,
        ),
        isNull,
      );
    });
  });

  group("lighting composition", () {
    test("N and R map independently to skybox and environment intensity", () {
      final profile = _profile("synthetic", "a05", nebula: 0.8, reflection: 1.6);
      final intensities = lightingIntensities(profile);
      expect(intensities.environmentIntensity, closeTo(1.6, 1e-12));
      expect(intensities.skyboxIntensity, closeTo(0.5, 1e-12));
      expect(intensities.environmentIntensity * intensities.skyboxIntensity, closeTo(0.8, 1e-12));
    });

    test("effective SH adds unscaled ambient after R multiplication in multiple directions", () {
      const reflection = 0.5;
      final ambient = vm.Vector3(0.2, 0.3, 0.4);
      final profile = _profile("synthetic", "a05", reflection: reflection, ambient: ambient);
      final base = [for (var i = 0; i < 9; i++) vm.Vector3(0.1 * (i + 1), -0.02 * i, 0.03 * i)];
      final effective = composeEffectiveDiffuseSh(base, profile)!;
      for (var i = 1; i < 9; i++) {
        _expectVector(effective[i], base[i]);
      }
      final scaled = [for (final coefficient in effective) coefficient * reflection];
      for (final normal in [vm.Vector3(1, 2, 3).normalized(), vm.Vector3(-2, 1, 4).normalized()]) {
        final expected = evaluateDiffuseSphericalHarmonics(base, normal) * reflection + ambient;
        final actual = evaluateDiffuseSphericalHarmonics(scaled, normal);
        _expectVector(actual, expected);
      }
    });

    test("ambient composition requires exactly 27 finite base floats", () {
      final profile = _profile("synthetic", "a05");
      expect(composeEffectiveDiffuseSh(null, profile), isNull);
      expect(composeEffectiveDiffuseSh(List.filled(8, vm.Vector3.zero()), profile), isNull);
      final nonFinite = List.filled(9, vm.Vector3.zero());
      nonFinite[4] = vm.Vector3(double.nan, 0, 0);
      expect(composeEffectiveDiffuseSh(nonFinite, profile), isNull);
    });

    test(
      "catalog sun product becomes neutral-white scalar key intensity without double scaling",
      () {
        expect(kGenericItemPreviewLightingProfile.sunColor, vm.Vector3.all(3));
        expect(kGenericItemPreviewLightingProfile.keyIntensity, 3);
        expect(kFittingLightingProfile.sunColor, vm.Vector3.all(2));
        expect(kFittingLightingProfile.keyIntensity, 2);
      },
    );
  });

  group("missing SH", () {
    test("absent, malformed, and non-finite sidecar SH are unusable rather than zero-filled", () {
      SkyboxAsset assetWith(pb.SkyboxMetadata? metadata) =>
          SkyboxAsset(hdrBytes: Uint8List(0), metadata: metadata);
      expect(diffuseShCoefficients(assetWith(null)), isNull);
      expect(diffuseShCoefficients(assetWith(pb.SkyboxMetadata())), isNull);
      expect(
        diffuseShCoefficients(assetWith(pb.SkyboxMetadata()..diffuseSh.addAll(List.filled(3, 0)))),
        isNull,
      );
      expect(
        diffuseShCoefficients(
          assetWith(pb.SkyboxMetadata()..diffuseSh.addAll(List.filled(27, double.infinity))),
        ),
        isNull,
      );
    });
  });

  group("key-light direction", () {
    test("camera-forward equals normalized target-minus-position after orbit and reset", () {
      final profile = _profile("amarr", "a05");
      final target = vm.Vector3(1, 2, 3);
      final initial = PerspectiveCamera(position: target + vm.Vector3(0, 0, -5), target: target);
      final orbited = PerspectiveCamera(position: target + vm.Vector3(4, -2, 3), target: target);
      final light = DirectionalLight(direction: vm.Vector3(1, 0, 0));

      updateKeyLightDirection(light, profile, initial);
      _expectVector(light.direction, (initial.target - initial.position).normalized());
      updateKeyLightDirection(light, profile, orbited);
      _expectVector(light.direction, (orbited.target - orbited.position).normalized());
      updateKeyLightDirection(light, profile, initial); // reset
      _expectVector(light.direction, (initial.target - initial.position).normalized());
      expect(light.intensity, 3);
    });

    test("fixed fitting direction does not follow the camera", () {
      final direction = kFittingLightingProfile.fixedSunDirection!;
      final first = PerspectiveCamera(position: vm.Vector3(0, 0, -5), target: vm.Vector3.zero());
      final second = PerspectiveCamera(position: vm.Vector3(5, 2, 1), target: vm.Vector3.zero());
      _expectVector(keyLightDirectionForCamera(kFittingLightingProfile, first)!, direction);
      _expectVector(keyLightDirectionForCamera(kFittingLightingProfile, second)!, direction);
    });

    test("a degenerate camera leaves the existing light direction unchanged", () {
      final position = vm.Vector3(1, 2, 3);
      final camera = PerspectiveCamera(position: position, target: position.clone());
      final light = DirectionalLight(direction: vm.Vector3(0, 1, 0));
      updateKeyLightDirection(light, _profile("amarr", "a05"), camera);
      _expectVector(light.direction, vm.Vector3(0, 1, 0));
    });
  });

  group("SkyboxEnvironmentCache", () {
    Future<EnvironmentMap> pending() => Completer<EnvironmentMap>().future;
    final profile = _profile("amarr", "a05");
    SkyboxEnvironmentCacheKey key(
      String id, {
      String? assetIdentity,
      vm.Vector3? ambient,
      double reflection = 1,
    }) => skyboxEnvironmentCacheKey(
      assetIdentity ?? "hash-$id",
      id,
      _profile("synthetic", id, ambient: ambient, reflection: reflection),
    );

    test("getOrBuild returns the in-flight build for repeat identical tuples", () {
      final cache = SkyboxEnvironmentCache();
      var builds = 0;
      Future<EnvironmentMap> build() {
        builds++;
        return pending();
      }

      final identity = skyboxEnvironmentCacheKey("hash-a05", "a05", profile);
      final first = cache.getOrBuild(identity, build);
      expect(identical(cache.getOrBuild(identity, build), first), isTrue);
      expect(builds, 1);
    });

    test("same skybox id with a different asset identity does not share entries", () {
      final cache = SkyboxEnvironmentCache();
      var builds = 0;
      Future<EnvironmentMap> build() {
        builds++;
        return pending();
      }

      final first = cache.getOrBuild(key("a05", assetIdentity: "hash-a05-v1"), build);
      expect(
        identical(cache.getOrBuild(key("a05", assetIdentity: "hash-a05-v2"), build), first),
        isFalse,
      );
      expect(builds, 2);
    });

    test("same skybox with different ambient or reflection does not share entries", () {
      final cache = SkyboxEnvironmentCache();
      var builds = 0;
      Future<EnvironmentMap> build() {
        builds++;
        return pending();
      }

      final base = key("a05");
      final first = cache.getOrBuild(base, build);
      expect(identical(cache.getOrBuild(base, build), first), isTrue);
      unawaited(cache.getOrBuild(key("a05", ambient: vm.Vector3(0.2, 0.25, 0.3)), build));
      unawaited(cache.getOrBuild(key("a05", reflection: 1.5), build));
      expect(builds, 3);
    });

    test("evicts least-recently-used entries beyond maxEntries", () {
      final cache = SkyboxEnvironmentCache();
      var builds = 0;
      Future<EnvironmentMap> build() {
        builds++;
        return pending();
      }

      final a01 = cache.getOrBuild(key("a01"), build);
      for (final id in ["c01", "g01", "m01"]) {
        unawaited(cache.getOrBuild(key(id), build));
      }
      expect(identical(cache.getOrBuild(key("a01"), build), a01), isTrue);
      unawaited(cache.getOrBuild(key("j01"), build));
      expect(builds, 5);
      unawaited(cache.getOrBuild(key("c01"), build));
      expect(builds, 6);
      expect(identical(cache.getOrBuild(key("a01"), build), a01), isTrue);
    });

    test("discard drops only the identical superseded build", () {
      final cache = SkyboxEnvironmentCache();
      final identity = key("a01");
      final first = cache.getOrBuild(identity, pending);
      cache.discard(identity, first);
      final second = cache.getOrBuild(identity, pending);
      expect(identical(first, second), isFalse);
      cache.discard(identity, first);
      expect(identical(cache.getOrBuild(identity, pending), second), isTrue);
    });

    test("evictExcept keeps only the active entry", () {
      final cache = SkyboxEnvironmentCache();
      final aKey = key("a01");
      final cKey = key("c01");
      final a01 = cache.getOrBuild(aKey, pending);
      unawaited(cache.getOrBuild(cKey, pending));
      cache.evictExcept(aKey);
      expect(identical(cache.getOrBuild(aKey, pending), a01), isTrue);
      var rebuilt = false;
      unawaited(
        cache.getOrBuild(cKey, () {
          rebuilt = true;
          return pending();
        }),
      );
      expect(rebuilt, isTrue);
    });
  });
}
