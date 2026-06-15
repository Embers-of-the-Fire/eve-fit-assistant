import "dart:convert";

import "package:eve_fit_assistant/storage/repo/models/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("ManifestIndex", () {
    test("JSON round-trip", () {
      final index = ManifestIndex(manifestVersion: 1, activatedGeneration: "gen-001");
      final restored = ManifestIndex.fromJson(
        jsonDecode(jsonEncode(index.toJson())) as Map<String, dynamic>,
      );
      expect(restored, index);
    });
  });

  group("GenerationsIndex", () {
    test("JSON round-trip", () {
      final index = GenerationsIndex(
        generations: IMap({
          "gen-001": GenerationEntry(
            id: "gen-001",
            createdAt: "2024-01-15T00:00:00Z",
            description: "First generation",
          ),
        }),
      );
      final restored = GenerationsIndex.fromJson(
        jsonDecode(jsonEncode(index.toJson())) as Map<String, dynamic>,
      );
      expect(restored, index);
    });

    test("JSON round-trip with empty generations", () {
      final index = GenerationsIndex();
      final restored = GenerationsIndex.fromJson(
        jsonDecode(jsonEncode(index.toJson())) as Map<String, dynamic>,
      );
      expect(restored.generations.isEmpty, isTrue);
      expect(restored, index);
    });
  });

  group("GenerationCatalog", () {
    test("JSON round-trip", () {
      final catalog = GenerationCatalog(
        catalogVersion: 1,
        createdAt: "2024-01-15T00:00:00Z",
        description: "Catalog description",
      );
      final restored = GenerationCatalog.fromJson(
        jsonDecode(jsonEncode(catalog.toJson())) as Map<String, dynamic>,
      );
      expect(restored, catalog);
    });
  });

  group("GenerationResources", () {
    test("JSON round-trip", () {
      final resources = GenerationResources(
        resourcesVersion: 1,
        servers: IMap({
          "serenity": GenerationServerEntry(
            lastUpdatedAt: "2024-01-15T00:00:00Z",
            name: IMap({"en": "Serenity", "zh": "晨曦"}),
          ),
        }),
      );
      final restored = GenerationResources.fromJson(
        jsonDecode(jsonEncode(resources.toJson())) as Map<String, dynamic>,
      );
      expect(restored, resources);
    });
  });

  group("GenerationServer", () {
    test("JSON round-trip", () {
      final server = GenerationServer(
        id: "serenity",
        lastUpdatedAt: "2024-01-15T00:00:00Z",
        metadata: GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX"),
        name: IMap({"en": "Serenity", "zh": "晨曦"}),
        checkouts: IList([
          GenerationCheckoutEntry(
            id: "checkout-hash-001",
            createdAt: "2024-01-15T00:00:00Z",
            metadata: GameMetadata(
              gameServer: "Serenity",
              gameBuild: "21.06",
              gameVersion: "EQUINOX",
            ),
          ),
        ]),
      );
      final restored = GenerationServer.fromJson(
        jsonDecode(jsonEncode(server.toJson())) as Map<String, dynamic>,
      );
      expect(restored, server);
    });

    test("JSON round-trip with empty checkouts", () {
      final server = GenerationServer(
        id: "serenity",
        lastUpdatedAt: "2024-01-15T00:00:00Z",
        metadata: GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX"),
      );
      final restored = GenerationServer.fromJson(
        jsonDecode(jsonEncode(server.toJson())) as Map<String, dynamic>,
      );
      expect(restored.checkouts.isEmpty, isTrue);
    });
  });

  group("GenerationCheckoutEntry", () {
    test("JSON round-trip", () {
      final entry = GenerationCheckoutEntry(
        id: "checkout-hash-001",
        createdAt: "2024-01-15T00:00:00Z",
        metadata: GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX"),
      );
      final restored = GenerationCheckoutEntry.fromJson(
        jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>,
      );
      expect(restored, entry);
    });
  });

  group("GenerationCheckoutCatalog", () {
    test("JSON round-trip", () {
      final catalog = GenerationCheckoutCatalog(
        id: "checkout-hash-001",
        createdAt: "2024-01-15T00:00:00Z",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX"),
        files: IMap({
          "data/types.json": AssetFile(pathHash: "abcd1234", hash: "efgh5678", size: 1024),
        }),
      );
      final restored = GenerationCheckoutCatalog.fromJson(
        jsonDecode(jsonEncode(catalog.toJson())) as Map<String, dynamic>,
      );
      expect(restored, catalog);
    });
  });

  group("AnnouncementCatalog", () {
    test("JSON round-trip", () {
      final catalog = AnnouncementCatalog(
        announcementsVersion: 1,
        announcements: IMap({
          "ann-001": AnnouncementCatalogEntry(
            id: "ann-001",
            firstPublishedAt: "2024-01-15T00:00:00Z",
            updatedAt: "2024-01-16T00:00:00Z",
            contentHash: "content-hash-001",
          ),
        }),
      );
      final restored = AnnouncementCatalog.fromJson(
        jsonDecode(jsonEncode(catalog.toJson())) as Map<String, dynamic>,
      );
      expect(restored, catalog);
    });
  });

  group("AnnouncementCatalogEntry", () {
    test("JSON round-trip with versionRange", () {
      final entry = AnnouncementCatalogEntry(
        id: "ann-001",
        firstPublishedAt: "2024-01-15T00:00:00Z",
        updatedAt: "2024-01-16T00:00:00Z",
        contentHash: "content-hash-001",
        isVersionUpdate: true,
        versionRange: VersionRange(min: "1.0.0", max: "2.0.0"),
      );
      final restored = AnnouncementCatalogEntry.fromJson(
        jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>,
      );
      expect(restored, entry);
    });
  });

  group("ReleaseCatalog", () {
    test("JSON round-trip", () {
      final catalog = ReleaseCatalog(
        releasesVersion: 1,
        releases: IMap({
          "rel-001": ReleaseCatalogEntry(
            id: "rel-001",
            createdAt: "2024-01-15T00:00:00Z",
            version: "1.0.0",
            offering: IList(["apk"]),
          ),
        }),
      );
      final restored = ReleaseCatalog.fromJson(
        jsonDecode(jsonEncode(catalog.toJson())) as Map<String, dynamic>,
      );
      expect(restored, catalog);
    });
  });

  group("ReleaseCatalogEntry", () {
    test("JSON round-trip", () {
      final entry = ReleaseCatalogEntry(
        id: "rel-001",
        createdAt: "2024-01-15T00:00:00Z",
        version: "1.0.0",
        offering: IList(["apk"]),
      );
      final restored = ReleaseCatalogEntry.fromJson(
        jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>,
      );
      expect(restored, entry);
    });
  });

  group("GenerationEntry", () {
    test("JSON round-trip", () {
      final entry = GenerationEntry(
        id: "gen-001",
        createdAt: "2024-01-15T00:00:00Z",
        description: "First generation",
      );
      final restored = GenerationEntry.fromJson(
        jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>,
      );
      expect(restored, entry);
    });
  });

  group("GenerationServerEntry", () {
    test("JSON round-trip", () {
      final entry = GenerationServerEntry(
        lastUpdatedAt: "2024-01-15T00:00:00Z",
        name: IMap({"en": "Serenity", "zh": "晨曦"}),
      );
      final restored = GenerationServerEntry.fromJson(
        jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>,
      );
      expect(restored, entry);
    });
  });

  group("Fixture deserialization", () {
    test("ManifestIndex from known JSON", () {
      final json =
          jsonDecode(
                '{'
                '  "manifestVersion": 1,'
                '  "activatedGeneration": "gen-2024-q1"'
                '}',
              )
              as Map<String, dynamic>;
      final index = ManifestIndex.fromJson(json);
      expect(index.manifestVersion, 1);
      expect(index.activatedGeneration, "gen-2024-q1");
    });

    test("GenerationsIndex from known JSON", () {
      final json =
          jsonDecode(
                '{'
                '  "generations": {'
                '    "gen-001": {'
                '      "id": "gen-001",'
                '      "createdAt": "2024-01-15T00:00:00Z",'
                '      "description": "First generation"'
                '    },'
                '    "gen-002": {'
                '      "id": "gen-002",'
                '      "createdAt": "2024-03-01T00:00:00Z",'
                '      "description": "Second generation"'
                '    }'
                '  }'
                '}',
              )
              as Map<String, dynamic>;
      final index = GenerationsIndex.fromJson(json);
      expect(index.generations["gen-001"]!.id, "gen-001");
      expect(index.generations["gen-001"]!.description, "First generation");
      expect(index.generations["gen-002"]!.id, "gen-002");
      expect(index.generations["gen-002"]!.createdAt, "2024-03-01T00:00:00Z");
    });

    test("GenerationCatalog from known JSON", () {
      final json =
          jsonDecode(
                '{'
                '  "catalogVersion": 3,'
                '  "createdAt": "2024-01-15T00:00:00Z",'
                '  "description": "Generation 2024-Q1 catalog"'
                '}',
              )
              as Map<String, dynamic>;
      final catalog = GenerationCatalog.fromJson(json);
      expect(catalog.catalogVersion, 3);
      expect(catalog.createdAt, "2024-01-15T00:00:00Z");
      expect(catalog.description, "Generation 2024-Q1 catalog");
    });

    test("GenerationResources from known JSON", () {
      final json =
          jsonDecode(
                '{'
                '  "resourcesVersion": 2,'
                '  "servers": {'
                '    "serenity": {'
                '      "lastUpdatedAt": "2024-01-15T00:00:00Z",'
                '      "name": {"en": "Serenity", "zh": "晨曦"}'
                '    },'
                '    "singularity": {'
                '      "lastUpdatedAt": "2024-03-01T00:00:00Z",'
                '      "name": {"en": "Singularity"}'
                '    }'
                '  }'
                '}',
              )
              as Map<String, dynamic>;
      final resources = GenerationResources.fromJson(json);
      expect(resources.resourcesVersion, 2);
      expect(resources.servers["serenity"]!.name["en"], "Serenity");
      expect(resources.servers["serenity"]!.name["zh"], "晨曦");
      expect(resources.servers["singularity"]!.lastUpdatedAt, "2024-03-01T00:00:00Z");
    });

    test("GenerationServer from known JSON", () {
      final json =
          jsonDecode(
                '{'
                '  "id": "serenity",'
                '  "lastUpdatedAt": "2024-01-15T00:00:00Z",'
                '  "name": {"en": "Serenity", "zh": "晨曦"},'
                '  "metadata": {"gameServer": "Serenity", "gameBuild": "21.06", "gameVersion": "EQUINOX"},'
                '  "checkouts": ['
                '    {'
                '      "id": "abc123def456",'
                '      "createdAt": "2024-01-10T00:00:00Z",'
                '      "metadata": {"gameServer": "Serenity", "gameBuild": "21.06", "gameVersion": "EQUINOX"}'
                '    },'
                '    {'
                '      "id": "def789ghi012",'
                '      "createdAt": "2024-01-14T00:00:00Z",'
                '      "metadata": {"gameServer": "Serenity", "gameBuild": "21.06", "gameVersion": "EQUINOX"}'
                '    }'
                '  ]'
                '}',
              )
              as Map<String, dynamic>;
      final server = GenerationServer.fromJson(json);
      expect(server.id, "serenity");
      expect(server.metadata.gameServer, "Serenity");
      expect(server.checkouts.length, 2);
      expect(server.checkouts.first.id, "abc123def456");
      expect(server.checkouts.last.id, "def789ghi012");
      expect(server.checkouts.first.metadata.gameVersion, "EQUINOX");
    });

    test("GenerationCheckoutEntry from known JSON", () {
      final json =
          jsonDecode(
                '{'
                '  "id": "abc123def456",'
                '  "createdAt": "2024-01-10T00:00:00Z",'
                '  "metadata": {"gameServer": "Serenity", "gameBuild": "21.06", "gameVersion": "EQUINOX"}'
                '}',
              )
              as Map<String, dynamic>;
      final entry = GenerationCheckoutEntry.fromJson(json);
      expect(entry.id, "abc123def456");
      expect(entry.createdAt, "2024-01-10T00:00:00Z");
      expect(entry.metadata.gameBuild, "21.06");
    });

    test("GenerationCheckoutCatalog from known JSON", () {
      final json =
          jsonDecode(
                '{'
                '  "id": "abc123def456",'
                '  "createdAt": "2024-01-10T00:00:00Z",'
                '  "serverId": "serenity",'
                '  "metadata": {"gameServer": "Serenity", "gameBuild": "21.06", "gameVersion": "EQUINOX"},'
                '  "files": {'
                '    "data/types.json": {"pathHash": "hash1", "hash": "filehash1", "size": 1024},'
                '    "data/groups.json": {"pathHash": "hash2", "hash": "filehash2", "size": 2048}'
                '  }'
                '}',
              )
              as Map<String, dynamic>;
      final catalog = GenerationCheckoutCatalog.fromJson(json);
      expect(catalog.id, "abc123def456");
      expect(catalog.serverId, "serenity");
      expect(catalog.files["data/types.json"]!.hash, "filehash1");
      expect(catalog.files["data/types.json"]!.size, 1024);
      expect(catalog.files["data/groups.json"]!.pathHash, "hash2");
    });

    test("AnnouncementCatalog from known JSON with optional versionRange", () {
      final json =
          jsonDecode(
                '{'
                '  "announcementsVersion": 1,'
                '  "announcements": {'
                '    "ann-001": {'
                '      "id": "ann-001",'
                '      "firstPublishedAt": "2024-01-15T00:00:00Z",'
                '      "updatedAt": "2024-01-16T00:00:00Z",'
                '      "contentHash": "hash-abc",'
                '      "isVersionUpdate": false'
                '    },'
                '    "ann-002": {'
                '      "id": "ann-002",'
                '      "firstPublishedAt": "2024-02-01T00:00:00Z",'
                '      "updatedAt": "2024-02-01T00:00:00Z",'
                '      "contentHash": "hash-def",'
                '      "versionRange": {"min": "1.0.0", "max": "2.0.0"},'
                '      "isVersionUpdate": true'
                '    }'
                '  }'
                '}',
              )
              as Map<String, dynamic>;
      final catalog = AnnouncementCatalog.fromJson(json);
      expect(catalog.announcementsVersion, 1);
      expect(catalog.announcements["ann-001"]!.isVersionUpdate, false);
      expect(catalog.announcements["ann-001"]!.versionRange, isNull);
      expect(catalog.announcements["ann-002"]!.isVersionUpdate, true);
      expect(catalog.announcements["ann-002"]!.versionRange!.min, "1.0.0");
      expect(catalog.announcements["ann-002"]!.versionRange!.max, "2.0.0");
    });

    test("ReleaseCatalog from known JSON", () {
      final json =
          jsonDecode(
                '{'
                '  "releasesVersion": 1,'
                '  "releases": {'
                '    "rel-001": {'
                '      "id": "rel-001",'
                '      "createdAt": "2024-01-15T00:00:00Z",'
                '      "version": "1.0.0",'
                '      "offering": ["apk", "website"]'
                '    },'
                '    "rel-002": {'
                '      "id": "rel-002",'
                '      "createdAt": "2024-02-01T00:00:00Z",'
                '      "version": "1.1.0",'
                '      "offering": ["apk"]'
                '    }'
                '  }'
                '}',
              )
              as Map<String, dynamic>;
      final catalog = ReleaseCatalog.fromJson(json);
      expect(catalog.releasesVersion, 1);
      expect(catalog.releases["rel-001"]!.version, "1.0.0");
      expect(catalog.releases["rel-001"]!.offering, IList(["apk", "website"]));
      expect(catalog.releases["rel-002"]!.createdAt, "2024-02-01T00:00:00Z");
      expect(catalog.releases["rel-002"]!.offering, IList(["apk"]));
    });
  });
}
