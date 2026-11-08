import "dart:async";
import "dart:collection";

import "package:efa_proto/types.pb.dart" as pb_types;
import "package:eve_fit_assistant/storage/repo/lighting_profile.dart";
import "package:eve_fit_assistant/storage/repo/skybox_asset.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:flutter_scene/scene.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";
import "package:vector_math/vector_math.dart" as vm;

part "skybox_environment.g.dart";

/// The sentinel environment selection resolving the skybox from the active
/// lighting profile at view time.
const String kShipModelSkyboxAuto = "auto";

/// The viewer's lighting presentation. This is independent of the skybox
/// setting, which selects environment assets only.
enum ShipModelLightingMode { itemPreview, fitting }

/// EVE race id → its item-preview profile id.
const Map<int, String> kRaceLightingProfiles = {
  4: "amarr",
  1: "caldari",
  8: "gallente",
  2: "minmatar",
  16: "jove",
  135: "triglavian",
};

/// Faction id → dedicated item-preview profile id.
const Map<int, String> kFactionLightingProfiles = {
  500019: "sansha", // Sansha's Nation
  500011: "angel", // Angel Cartel
  500006: "concord", // CONCORD Assembly
  500018: "mordu", // Mordu's Legion
  500014: "ore", // ORE
  500017: "soct", // Society of Conscious Thought
  500016: "soe", // Sisters of EVE
  500026: "triglavian", // Triglavian Collective
};

/// Existing race-based environment fallback when the active profile's own
/// environment is absent from an older snapshot.
const Map<int, String> kRaceSkyboxDefaults = {
  4: "a05",
  1: "c05",
  8: "g04",
  2: "m01",
  16: "m10",
  135: "ad01_a",
};

/// Existing faction-based environment fallback for dedicated preview scenes.
const Map<int, String> kFactionSkyboxDefaults = {
  500019: "a10",
  500011: "m01",
  500006: "c18",
  500018: "c02",
  500014: "c06",
  500017: "g06",
  500016: "c07",
  500026: "ad01_a",
};

const String kGenericSkyboxId = "m10";
const String kFittingSkyboxId = "fitting";

/// The descriptor-derived profile id requested by mode and type, before
/// catalog presence/validation fallbacks.
String requestedLightingProfileId({
  required ShipModelLightingMode mode,
  required pb_types.Type? type,
  required List<int>? Function(int factionId) factionMemberRaces,
}) {
  if (mode == ShipModelLightingMode.fitting) return "fitting";
  if (type != null && type.hasFactionId()) {
    final factionProfile = kFactionLightingProfiles[type.factionId];
    if (factionProfile != null) return factionProfile;
    final memberRaces = factionMemberRaces(type.factionId);
    if (memberRaces != null && memberRaces.isNotEmpty) {
      return kRaceLightingProfiles[memberRaces.first] ?? "generic";
    }
  }
  if (type != null && type.hasRaceId()) return kRaceLightingProfiles[type.raceId] ?? "generic";
  return "generic";
}

/// Resolves the active lighting profile from the viewer mode and viewed type.
/// Environment overrides deliberately play no part in this operation.
AppLightingProfile resolveLightingProfile({
  required ShipModelLightingMode mode,
  required Map<String, AppLightingProfile>? profiles,
  required pb_types.Type? type,
  required List<int>? Function(int factionId) factionMemberRaces,
}) {
  if (mode == ShipModelLightingMode.fitting) {
    final fitting = profiles?["fitting"];
    if (fitting != null && fitting.kind == AppLightingProfileKind.fitting) return fitting;
    // Only an unavailable catalog uses the fitting compatibility profile. A
    // valid catalog without fitting follows the same generic chain as any
    // other requested profile that is absent.
    if (profiles == null) return kFittingLightingProfile;
    final generic = profiles["generic"];
    return generic != null && generic.kind == AppLightingProfileKind.itemPreview
        ? generic
        : kGenericItemPreviewLightingProfile;
  }

  final profileId = requestedLightingProfileId(
    mode: mode,
    type: type,
    factionMemberRaces: factionMemberRaces,
  );
  final selected = profiles?[profileId];
  if (selected != null && selected.kind == AppLightingProfileKind.itemPreview) return selected;
  final generic = profiles?["generic"];
  if (generic != null && generic.kind == AppLightingProfileKind.itemPreview) return generic;
  return kGenericItemPreviewLightingProfile;
}

/// Resolves environment assets independently of the active lighting profile.
/// A valid concrete [setting] is always an environment-only override.
String? resolveEnvironmentId({
  required String setting,
  required ShipModelLightingMode mode,
  required AppLightingProfile activeProfile,
  required SkyboxAssetService service,
  required pb_types.Type? type,
  required List<int>? Function(int factionId) factionMemberRaces,
}) {
  if (setting != kShipModelSkyboxAuto && service.hasSkybox(setting)) return setting;

  if (mode == ShipModelLightingMode.fitting) {
    if (service.hasSkybox(kFittingSkyboxId)) return kFittingSkyboxId;
    return service.hasSkybox(kGenericSkyboxId) ? kGenericSkyboxId : null;
  }

  if (service.hasSkybox(activeProfile.skyboxId)) return activeProfile.skyboxId;

  // Older snapshots can lack the profile's newly mapped environment. Preserve
  // the existing faction/member-race/type-race chain before the generic cube.
  if (type != null && type.hasFactionId()) {
    final factionDefault = kFactionSkyboxDefaults[type.factionId];
    if (factionDefault != null && service.hasSkybox(factionDefault)) return factionDefault;
  }

  int? raceId;
  if (type != null && type.hasFactionId()) {
    final memberRaces = factionMemberRaces(type.factionId);
    if (memberRaces != null && memberRaces.isNotEmpty) raceId = memberRaces.first;
  }
  if (raceId == null && type != null && type.hasRaceId()) raceId = type.raceId;
  final raceDefault = raceId == null ? null : kRaceSkyboxDefaults[raceId];
  if (raceDefault != null && service.hasSkybox(raceDefault)) return raceDefault;

  return service.hasSkybox(kGenericSkyboxId) ? kGenericSkyboxId : null;
}

/// The 27 finite sidecar floats as nine RGB coefficients, or `null` when no
/// usable precomputed diffuse SH is available.
List<vm.Vector3>? diffuseShCoefficients(SkyboxAsset asset) {
  final sh = asset.metadata?.diffuseSh;
  if (sh == null || sh.length != 27 || sh.any((value) => !value.isFinite)) return null;
  return [for (var i = 0; i < 9; i++) vm.Vector3(sh[i * 3], sh[i * 3 + 1], sh[i * 3 + 2])];
}

/// Composes profile ambient into band 0 so subsequent multiplication by the
/// scene's reflection intensity produces `R * baseSH(N) + ambientColor`.
/// Returns `null` for anything other than nine finite RGB coefficients (27
/// finite floats); callers must not substitute a zero-filled SH.
List<vm.Vector3>? composeEffectiveDiffuseSh(List<vm.Vector3>? baseSh, AppLightingProfile profile) {
  if (!profile.reflectionIntensity.isFinite || profile.reflectionIntensity <= 0) {
    throw ArgumentError.value(
      profile.reflectionIntensity,
      "profile.reflectionIntensity",
      "Must be finite and positive",
    );
  }
  if (baseSh == null ||
      baseSh.length != 9 ||
      baseSh.any(
        (coefficient) =>
            !coefficient.x.isFinite || !coefficient.y.isFinite || !coefficient.z.isFinite,
      )) {
    return null;
  }

  final effective = [for (final coefficient in baseSh) coefficient.clone()];
  effective[0].add(profile.ambientColor / (profile.reflectionIntensity * kShBand0Basis));
  return effective;
}

/// Independent flutter_scene intensity inputs for a profile. The visible
/// background receives `environmentIntensity * skyboxIntensity == N`.
({double environmentIntensity, double skyboxIntensity}) lightingIntensities(
  AppLightingProfile profile,
) {
  if (!profile.reflectionIntensity.isFinite || profile.reflectionIntensity <= 0) {
    throw ArgumentError.value(
      profile.reflectionIntensity,
      "profile.reflectionIntensity",
      "Must be finite and positive",
    );
  }
  return (
    environmentIntensity: profile.reflectionIntensity,
    skyboxIntensity: profile.nebulaIntensity / profile.reflectionIntensity,
  );
}

/// Every input that changes a built environment. The [assetIdentity] scopes
/// the entry to the exact HDR/sidecar bytes of the active checkout: a checkout
/// that ships different content for the same skybox id must not reuse the
/// previous build. Profile id and camera motion deliberately do not appear
/// here; equal tuples share their GPU environment.
typedef SkyboxEnvironmentCacheKey = ({
  String assetIdentity,
  String skyboxId,
  double ambientRed,
  double ambientGreen,
  double ambientBlue,
  double reflectionIntensity,
});

/// The cache key for skybox [skyboxId] under [profile]; [assetIdentity] is
/// [SkyboxAssetService.skyboxAssetIdentity] for the same checkout.
SkyboxEnvironmentCacheKey skyboxEnvironmentCacheKey(
  String assetIdentity,
  String skyboxId,
  AppLightingProfile profile,
) => (
  assetIdentity: assetIdentity,
  skyboxId: skyboxId,
  ambientRed: profile.ambientColor.x,
  ambientGreen: profile.ambientColor.y,
  ambientBlue: profile.ambientColor.z,
  reflectionIntensity: profile.reflectionIntensity,
);

/// Computes the app-space key travel direction without modifying the scene.
/// A degenerate camera has no forward direction and returns `null`.
vm.Vector3? keyLightDirectionForCamera(AppLightingProfile profile, PerspectiveCamera camera) {
  if (profile.sunDirectionMode == AppSunDirectionMode.fixed) {
    final fixed = profile.fixedSunDirection;
    return fixed?.clone();
  }
  final delta = camera.target - camera.position;
  if (!delta.x.isFinite || !delta.y.isFinite || !delta.z.isFinite || delta.length2 <= 0) {
    return null;
  }
  return delta.normalized();
}

/// Mutates the existing key light's direction on a camera update.
void updateKeyLightDirection(
  DirectionalLight light,
  AppLightingProfile profile,
  PerspectiveCamera camera,
) {
  final direction = keyLightDirectionForCamera(profile, camera);
  if (direction != null) light.direction = direction;
}

/// App-wide cache of built skybox [EnvironmentMap]s (LRU, at most
/// [maxEntries] entries). Entries include in-flight builds; superseded builds
/// are discarded through [discard].
class SkyboxEnvironmentCache {
  /// Maximum cached environments (LRU).
  static const int maxEntries = 4;

  final LinkedHashMap<SkyboxEnvironmentCacheKey, Future<EnvironmentMap>> _entries = LinkedHashMap();

  /// The cached (or in-flight) environment build for [key], building it with
  /// [build] on a miss.
  Future<EnvironmentMap> getOrBuild(
    SkyboxEnvironmentCacheKey key,
    Future<EnvironmentMap> Function() build,
  ) {
    final existing = _entries.remove(key);
    if (existing != null) {
      _entries[key] = existing; // mark most-recently-used
      return existing;
    }
    final future = build();
    _entries[key] = future;
    while (_entries.length > maxEntries) {
      unawaited(_entries.remove(_entries.keys.first));
    }
    return future;
  }

  /// Drops the cached build for [key] when it is still [future].
  void discard(SkyboxEnvironmentCacheKey key, Future<EnvironmentMap> future) {
    if (identical(_entries[key], future)) unawaited(_entries.remove(key));
  }

  /// Memory pressure: evict every entry but [activeKey].
  void evictExcept(SkyboxEnvironmentCacheKey? activeKey) {
    _entries.removeWhere((key, _) => key != activeKey);
  }
}

/// App-wide skybox environment cache (LRU, see [SkyboxEnvironmentCache]).
@riverpodSingleton
SkyboxEnvironmentCache skyboxEnvironmentCache(Ref ref) => SkyboxEnvironmentCache();
