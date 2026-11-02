@TestOn("vm")
library;

import "dart:async";

import "package:efa_proto/resource_index.pb.dart";
import "package:efa_proto/types.pb.dart" as pb_types;
import "package:eve_fit_assistant/components/model/skybox_environment.dart";
import "package:eve_fit_assistant/storage/fs/memory_blob_store.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:eve_fit_assistant/storage/repo/skybox_asset.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_scene/scene.dart";
import "package:flutter_test/flutter_test.dart";

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

  group("resolveSkyboxId", () {
    final service = serviceWithCatalog([
      "a01",
      "a05",
      "a10",
      "c01",
      "c02",
      "c05",
      "c06",
      "c07",
      "c18",
      "g04",
      "g06",
      "m01",
      "m10",
      "ad01_a",
      "wormhole_class_01",
    ]);

    test("a concrete setting wins verbatim, for every ship", () {
      final type = pb_types.Type()..raceId = 2;
      expect(
        resolveSkyboxId(
          setting: "wormhole_class_01",
          service: service,
          type: type,
          factionMemberRaces: noFactions,
        ),
        "wormhole_class_01",
      );
    });

    test("a stored id missing from the catalog behaves as auto", () {
      final type = pb_types.Type()..raceId = 2; // Minmatar
      expect(
        resolveSkyboxId(
          setting: "removed_skybox",
          service: service,
          type: type,
          factionMemberRaces: noFactions,
        ),
        "m01",
      );
    });

    test("auto resolves each race's authentic item-preview skybox", () {
      final expectations = {4: "a05", 1: "c05", 8: "g04", 2: "m01", 16: "m10", 135: "ad01_a"};
      for (final entry in expectations.entries) {
        expect(
          resolveSkyboxId(
            setting: "auto",
            service: service,
            type: pb_types.Type()..raceId = entry.key,
            factionMemberRaces: noFactions,
          ),
          entry.value,
          reason: "race ${entry.key}",
        );
      }
    });

    test("factions with a dedicated preview scene win over the race", () {
      final expectations = {
        500019: "a10", // Sansha's Nation
        500011: "m01", // Angel Cartel
        500006: "c18", // CONCORD Assembly
        500018: "c02", // Mordu's Legion
        500014: "c06", // ORE
        500017: "g06", // Society of Conscious Thought
        500016: "c07", // Sisters of EVE
        500026: "ad01_a", // Triglavian Collective
      };
      for (final entry in expectations.entries) {
        final type = pb_types.Type()
          ..raceId = 2 // Minmatar hull; the faction's scene must win
          ..factionId = entry.key;
        expect(
          resolveSkyboxId(
            setting: "auto",
            service: service,
            type: type,
            factionMemberRaces: noFactions,
          ),
          entry.value,
          reason: "faction ${entry.key}",
        );
      }
    });

    test("an unlisted faction follows its member race (pirate hulls)", () {
      final type = pb_types.Type()
        ..raceId = 2 // Minmatar hull...
        ..factionId = 500010; // ...flown by a Caldari pirate faction
      expect(
        resolveSkyboxId(
          setting: "auto",
          service: service,
          type: type,
          factionMemberRaces: (factionId) => factionId == 500010 ? [1] : null,
        ),
        "c05",
      );
    });

    test("an unknown faction falls back to the type race", () {
      final type = pb_types.Type()
        ..raceId = 2
        ..factionId = 999999;
      expect(
        resolveSkyboxId(
          setting: "auto",
          service: service,
          type: type,
          factionMemberRaces: noFactions,
        ),
        "m01",
      );
    });

    test("an unmapped race falls back to the generic preview skybox", () {
      final type = pb_types.Type()..raceId = 128; // no preview scene
      expect(
        resolveSkyboxId(
          setting: "auto",
          service: service,
          type: type,
          factionMemberRaces: noFactions,
        ),
        "m10",
      );
    });

    test("a type without race or faction falls back to the generic skybox", () {
      expect(
        resolveSkyboxId(setting: "auto", service: service, type: pb_types.Type(), factionMemberRaces: noFactions),
        "m10",
      );
      expect(
        resolveSkyboxId(setting: "auto", service: service, type: null, factionMemberRaces: noFactions),
        "m10",
      );
    });

    test("a race default missing from the catalog falls back to generic", () {
      final gallente = pb_types.Type()..raceId = 8;
      expect(
        resolveSkyboxId(
          setting: "auto",
          service: serviceWithCatalog(["a01", "m10"]),
          type: gallente,
          factionMemberRaces: noFactions,
        ),
        "m10",
      );
    });

    test("no skybox only when even the generic one is absent from the catalog", () {
      expect(
        resolveSkyboxId(
          setting: "auto",
          service: serviceWithCatalog(["a01"]),
          type: pb_types.Type()..raceId = 8,
          factionMemberRaces: noFactions,
        ),
        isNull,
      );
    });
  });

  group("SkyboxEnvironmentCache", () {
    Future<EnvironmentMap> pending() => Completer<EnvironmentMap>().future;

    test("getOrBuild returns the in-flight build for repeat calls", () {
      final cache = SkyboxEnvironmentCache();
      var builds = 0;
      Future<EnvironmentMap> build() {
        builds++;
        return pending();
      }

      final first = cache.getOrBuild("a01", build);
      expect(identical(cache.getOrBuild("a01", build), first), isTrue);
      expect(builds, 1);
    });

    test("evicts least-recently-used entries beyond maxEntries", () {
      final cache = SkyboxEnvironmentCache();
      var builds = 0;
      Future<EnvironmentMap> build() {
        builds++;
        return pending();
      }

      final a01 = cache.getOrBuild("a01", build);
      for (final id in ["c01", "g01", "m01"]) {
        cache.getOrBuild(id, build);
      }
      // Touch a01 so it is no longer the oldest, then overflow with j01.
      expect(identical(cache.getOrBuild("a01", build), a01), isTrue);
      cache.getOrBuild("j01", build);
      expect(builds, 5);
      // c01 was the oldest untouched entry: evicted, rebuilt on demand.
      cache.getOrBuild("c01", build);
      expect(builds, 6);
      // a01 survived.
      expect(identical(cache.getOrBuild("a01", build), a01), isTrue);
    });

    test("discard drops only the identical superseded build", () {
      final cache = SkyboxEnvironmentCache();
      final first = cache.getOrBuild("a01", pending);

      cache.discard("a01", first); // the cached build: dropped
      final second = cache.getOrBuild("a01", pending);
      expect(identical(first, second), isFalse);

      cache.discard("a01", first); // stale future, no longer cached: no-op
      expect(identical(cache.getOrBuild("a01", pending), second), isTrue);
    });

    test("evictExcept keeps only the active entry", () {
      final cache = SkyboxEnvironmentCache();
      final a01 = cache.getOrBuild("a01", pending);
      cache.getOrBuild("c01", pending);
      cache.evictExcept("a01");
      expect(identical(cache.getOrBuild("a01", pending), a01), isTrue);
      var rebuilt = false;
      cache.getOrBuild("c01", () {
        rebuilt = true;
        return pending();
      });
      expect(rebuilt, isTrue);
    });
  });
}
