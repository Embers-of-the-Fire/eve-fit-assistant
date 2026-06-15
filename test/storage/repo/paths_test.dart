import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

void main() {
  setUp(() {
    PathProvider.documentsPath = "/fake/documents";
  });

  group("RepoPaths schema resource paths", () {
    test("schemaResourcesPath is under resourcesPath", () {
      expect(RepoPaths.schemaResourcesPath, p.join(PathProvider.resourcesPath, "v2"));
    });

    test("activePath is under schemaResourcesPath", () {
      expect(RepoPaths.activePath, p.join(RepoPaths.schemaResourcesPath, "active.json"));
    });

    test("schemaVersionPath is under schemaResourcesPath", () {
      expect(
        RepoPaths.schemaVersionPath,
        p.join(RepoPaths.schemaResourcesPath, "schema_version.json"),
      );
    });

    test("assetsPath is under schemaResourcesPath", () {
      expect(RepoPaths.assetsPath, p.join(RepoPaths.schemaResourcesPath, "assets"));
    });

    test("assetPath uses 2-char prefix from pathHash", () {
      const pathHash = "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890";
      const contentHash = "fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321";
      final assetPath = RepoPaths.assetPath(pathHash, contentHash);
      expect(assetPath, p.join(RepoPaths.assetsPath, "ab", pathHash, contentHash));
    });

    test("metadataPath is under schemaResourcesPath", () {
      expect(RepoPaths.metadataPath, p.join(RepoPaths.schemaResourcesPath, "metadata"));
    });

    test("checkoutsPath is under metadataPath", () {
      expect(RepoPaths.checkoutsPath, p.join(RepoPaths.metadataPath, "checkouts"));
    });

    test("checkoutsIndexPath is under checkoutsPath", () {
      expect(RepoPaths.checkoutsIndexPath, p.join(RepoPaths.checkoutsPath, "index.json"));
    });

    test("checkoutsRefsPath is under checkoutsPath", () {
      expect(RepoPaths.checkoutsRefsPath, p.join(RepoPaths.checkoutsPath, "refs.json"));
    });

    test("checkoutManifestPath uses checkout hash as directory", () {
      const checkoutId = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
      expect(
        RepoPaths.checkoutManifestPath(checkoutId),
        p.join(RepoPaths.checkoutsPath, checkoutId, "assets.json"),
      );
    });

    test("branchesPath is under schemaResourcesPath", () {
      expect(RepoPaths.branchesPath, p.join(RepoPaths.schemaResourcesPath, "branches"));
    });

    test("branchPath uses branchId as filename with .json extension", () {
      const branchId = "550e8400-e29b-41d4-a716-446655440000";
      expect(
        RepoPaths.branchPath(branchId),
        p.join(RepoPaths.branchesPath, "550e8400-e29b-41d4-a716-446655440000.json"),
      );
    });
  });

  group("RepoPaths runtime data paths", () {
    test("runtimeDataPath is under documentsPath", () {
      expect(
        RepoPaths.runtimeDataPath,
        p.join(PathProvider.documentsPath, "runtime", "v2", "data"),
      );
    });

    test("runtimeFittingsPath is under runtimeDataPath", () {
      expect(RepoPaths.runtimeFittingsPath, p.join(RepoPaths.runtimeDataPath, "fittings"));
    });

    test("fittingsRegistryPath is under runtimeFittingsPath", () {
      expect(
        RepoPaths.fittingsRegistryPath,
        p.join(RepoPaths.runtimeFittingsPath, "registry.json"),
      );
    });

    test("runtimeFittingPath uses fitId as filename with .json extension", () {
      const fitId = "my-fit-123";
      expect(
        RepoPaths.runtimeFittingPath(fitId),
        p.join(RepoPaths.runtimeFittingsPath, "my-fit-123.json"),
      );
    });

    test("runtimeCharactersPath is under runtimeDataPath", () {
      expect(RepoPaths.runtimeCharactersPath, p.join(RepoPaths.runtimeDataPath, "characters"));
    });

    test("charactersRegistryPath is under runtimeCharactersPath", () {
      expect(
        RepoPaths.charactersRegistryPath,
        p.join(RepoPaths.runtimeCharactersPath, "registry.json"),
      );
    });

    test("runtimeCharacterPath uses characterId as filename with .json extension", () {
      const characterId = "char-abc";
      expect(
        RepoPaths.runtimeCharacterPath(characterId),
        p.join(RepoPaths.runtimeCharactersPath, "char-abc.json"),
      );
    });

    test("runtimeAnnouncementsPath is under runtimeDataPath", () {
      expect(
        RepoPaths.runtimeAnnouncementsPath,
        p.join(RepoPaths.runtimeDataPath, "announcements"),
      );
    });

    test("announcementsIndexPath is under runtimeAnnouncementsPath", () {
      expect(
        RepoPaths.announcementsIndexPath,
        p.join(RepoPaths.runtimeAnnouncementsPath, "index.json"),
      );
    });

    test("announcementFilePath uses locale and id", () {
      expect(
        RepoPaths.announcementFilePath("en", "msg-001"),
        p.join(RepoPaths.runtimeAnnouncementsPath, "files", "en", "msg-001"),
      );
    });

    test("announcementRegistryPath uses id", () {
      expect(
        RepoPaths.announcementRegistryPath("msg-001"),
        p.join(RepoPaths.runtimeAnnouncementsPath, "registry", "msg-001.json"),
      );
    });
  });
}
