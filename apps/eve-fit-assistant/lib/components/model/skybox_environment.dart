import "dart:async";
import "dart:collection";

import "package:efa_proto/types.pb.dart" as pb_types;
import "package:eve_fit_assistant/storage/repo/skybox_asset.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:flutter_scene/scene.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";
import "package:vector_math/vector_math.dart" as vm;

part "skybox_environment.g.dart";

/// The sentinel skybox selection resolving the skybox from the viewed ship's
/// race at view time.
const String kShipModelSkyboxAuto = "auto";

/// EVE race id → the skybox of its authentic item-preview scene: the
/// `NebulaMap` referenced by `res:/dx9/scene/preview/<race>.black` (Amarr
/// a05, Caldari c05, Gallente g04, Minmatar m01, Jove m10, Triglavian
/// ad01_a). Race ids follow the client's appConst.py (`raceTriglavian` is
/// 135, not one of the empire bits).
const Map<int, String> kRaceSkyboxDefaults = {
  4: "a05",
  1: "c05",
  8: "g04",
  2: "m01",
  16: "m10",
  135: "ad01_a",
};

/// Faction id → preview skybox for factions with a dedicated preview scene
/// (`res:/dx9/scene/preview/<name>.black`); faction ids follow the client's
/// appConst.py. The sleeper/talocan preview scenes exist but no FSD faction
/// carries them, so those skyboxes are picker-only. Factions without a
/// dedicated scene (e.g. Guristas) fall through to their member race's
/// default — EVE falls back to the generic m10 there; following the parent
/// race is a deliberate app choice.
const Map<int, String> kFactionSkyboxDefaults = {
  500019: "a10", // Sansha's Nation — sansha.black
  500011: "m01", // Angel Cartel — angel.black
  500006: "c18", // CONCORD Assembly — concord.black
  500018: "c02", // Mordu's Legion — mordu.black
  500014: "c06", // ORE — ore.black
  500017: "g06", // Society of Conscious Thought — soct.black
  500016: "c07", // Sisters of EVE — soe.black
  500026: "ad01_a", // Triglavian Collective — triglavian.black
};

/// The generic preview scene's skybox (`generic.black` → m10, also the
/// jove/other/rogue previews) and the fallback when nothing else resolves.
const String kGenericSkyboxId = "m10";

/// Resolves the skybox id a ship view should render, mirroring EVE's
/// item-preview scenes:
///
/// 1. A concrete [setting] (not `auto`) wins, when the id is in the catalog;
///    a stored id the catalog no longer contains behaves as `auto` (the
///    stored value is not rewritten).
/// 2. `auto` prefers the type's `faction_id` when that faction has a
///    dedicated preview scene ([kFactionSkyboxDefaults]).
/// 3. Otherwise the faction's first member race ([factionMemberRaces],
///    FSD `memberRaces`) or the type's own `race_id` picks the race's
///    preview skybox ([kRaceSkyboxDefaults]).
/// 4. Otherwise the generic preview skybox ([kGenericSkyboxId]).
/// 5. A candidate missing from the catalog (e.g. an older snapshot) falls
///    through to the next step; if even the generic skybox is absent the
///    result is `null` and the viewer renders without a skybox (transparent
///    background, studio IBL). A normal state, not an error.
String? resolveSkyboxId({
  required String setting,
  required SkyboxAssetService service,
  required pb_types.Type? type,
  required List<int>? Function(int factionId) factionMemberRaces,
}) {
  if (setting != kShipModelSkyboxAuto && service.hasSkybox(setting)) return setting;

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

/// The 27-float sidecar SH as the 9 RGB coefficient vectors
/// `EnvironmentMap.fromEquirectImageBytes` expects, or `null` when the
/// sidecar is absent (its 27-float shape is enforced by
/// [SkyboxAssetService]).
List<vm.Vector3>? diffuseShCoefficients(SkyboxAsset asset) {
  final sh = asset.metadata?.diffuseSh;
  if (sh == null || sh.length != 27) return null;
  return [for (var i = 0; i < 9; i++) vm.Vector3(sh[i * 3], sh[i * 3 + 1], sh[i * 3 + 2])];
}

/// App-wide cache of built skybox [EnvironmentMap]s (LRU, at most
/// [maxEntries] entries).
///
/// Building an environment performs GPU work (radiance prefilter + texture
/// uploads), so it must not repeat per viewer: every ship view of the same
/// skybox shares one instance. Entries keyed by skybox id hold the in-flight
/// or completed build; superseded builds are discarded, not retained (see
/// [discard]). Under memory pressure [evictExcept] drops every entry but the
/// active one — `EnvironmentMap` owns no explicit dispose, so eviction is a
/// reference drop.
class SkyboxEnvironmentCache {
  /// Maximum cached environments (LRU).
  static const int maxEntries = 4;

  final LinkedHashMap<String, Future<EnvironmentMap>> _entries = LinkedHashMap();

  /// The cached (or in-flight) environment build for [id], building it with
  /// [build] on a miss.
  Future<EnvironmentMap> getOrBuild(String id, Future<EnvironmentMap> Function() build) {
    final existing = _entries.remove(id);
    if (existing != null) {
      _entries[id] = existing; // mark most-recently-used
      return existing;
    }
    final future = build();
    _entries[id] = future;
    while (_entries.length > maxEntries) {
      unawaited(_entries.remove(_entries.keys.first));
    }
    return future;
  }

  /// Drops the cached build for [id] when it is still [future] (a superseded
  /// build must not be cached).
  void discard(String id, Future<EnvironmentMap> future) {
    if (identical(_entries[id], future)) unawaited(_entries.remove(id));
  }

  /// Memory pressure: evict every entry but [activeId].
  void evictExcept(String? activeId) {
    _entries.removeWhere((id, _) => id != activeId);
  }
}

/// App-wide skybox environment cache (LRU, see [SkyboxEnvironmentCache]).
@riverpodSingleton
SkyboxEnvironmentCache skyboxEnvironmentCache(Ref ref) => SkyboxEnvironmentCache();
