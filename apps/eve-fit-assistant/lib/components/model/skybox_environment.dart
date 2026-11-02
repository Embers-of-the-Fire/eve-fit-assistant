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

/// EVE race id → its `universe` skybox prefix (the alphabetic prefix of the
/// universe skybox ids: Amarr `a`, Caldari `c`, Gallente `g`, Minmatar `m`,
/// Jove `j`). Races without a skybox prefix (e.g. Triglavian) resolve to no
/// skybox.
const Map<int, String> kRaceSkyboxPrefixes = {4: "a", 1: "c", 8: "g", 2: "m", 16: "j"};

/// Resolves the skybox id a ship view should render (spec §5.2):
///
/// 1. A concrete [setting] (not `auto`) wins, when the id is in the catalog;
///    a stored id the catalog no longer contains behaves as `auto` (the
///    stored value is not rewritten).
/// 2. `auto` takes the type's `faction_id` resolved through the official
///    `memberRaces` mapping first ([factionMemberRaces]; pirate hulls follow
///    their parent race), then its `race_id`, and maps the race to its
///    `universe` prefix.
/// 3. The default is the lowest-numbered catalog entry with that prefix.
/// 4. Nothing resolvable → `null`: the viewer renders without a skybox
///    (transparent background, studio IBL). A normal state, not an error.
String? resolveSkyboxId({
  required String setting,
  required SkyboxAssetService service,
  required pb_types.Type? type,
  required List<int>? Function(int factionId) factionMemberRaces,
}) {
  if (setting != kShipModelSkyboxAuto) {
    if (service.hasSkybox(setting)) return setting;
  }

  int? raceId;
  if (type != null && type.hasFactionId()) {
    final memberRaces = factionMemberRaces(type.factionId);
    if (memberRaces != null && memberRaces.isNotEmpty) raceId = memberRaces.first;
  }
  if (raceId == null && type != null && type.hasRaceId()) raceId = type.raceId;
  final prefix = raceId == null ? null : kRaceSkyboxPrefixes[raceId];
  if (prefix == null) return null;

  final catalog = service.listSkyboxes();
  final candidates = [
    for (final skybox in catalog)
      if (skybox.family == "universe" && skybox.id.startsWith(prefix)) skybox.id,
  ]..sort();
  return candidates.isEmpty ? null : candidates.first;
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
