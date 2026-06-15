import "package:eve_fit_assistant/config/paths.dart";
import "package:path/path.dart" as p;

/// Path resolution for all schema resource and runtime data directories.
class RepoPaths {
  const RepoPaths._();

  // ── Schema resources ────────────────────────────────────────────────────────

  static String get schemaResourcesPath => p.join(PathProvider.resourcesPath, "v2");

  static String get activePath => p.join(schemaResourcesPath, "active.json");

  static String get schemaVersionPath => p.join(schemaResourcesPath, "schema_version.json");

  // assets/
  static String get assetsPath => p.join(schemaResourcesPath, "assets");

  static String assetPath(String pathHash, String contentHash) {
    if (pathHash.length < 2) {
      throw ArgumentError.value(pathHash, "pathHash", "Must be at least 2 characters");
    }
    return p.join(assetsPath, pathHash.substring(0, 2), pathHash, contentHash);
  }

  static String assetContentDir(String pathHash) {
    if (pathHash.length < 2) {
      throw ArgumentError.value(pathHash, "pathHash", "Must be at least 2 characters");
    }
    return p.join(assetsPath, pathHash.substring(0, 2), pathHash);
  }

  // metadata/
  static String get metadataPath => p.join(schemaResourcesPath, "metadata");

  // metadata/checkouts/
  static String get checkoutsPath => p.join(metadataPath, "checkouts");

  static String get checkoutsIndexPath => p.join(checkoutsPath, "index.json");

  static String get checkoutsRefsPath => p.join(checkoutsPath, "refs.json");

  static String checkoutManifestPath(String checkoutId) =>
      p.join(checkoutsPath, checkoutId, "assets.json");

  // branches/
  static String get branchesPath => p.join(schemaResourcesPath, "branches");

  static String branchPath(String branchId) => p.join(branchesPath, "$branchId.json");

  // ── Runtime data ─────────────────────────────────────────────────────────────

  static String get runtimeDataPath => p.join(PathProvider.documentsPath, "runtime", "v2", "data");

  // fittings/
  static String get runtimeFittingsPath => p.join(runtimeDataPath, "fittings");

  static String get fittingsRegistryPath => p.join(runtimeFittingsPath, "registry.json");

  static String runtimeFittingPath(String fitId) => p.join(runtimeFittingsPath, "$fitId.json");

  // characters/
  static String get runtimeCharactersPath => p.join(runtimeDataPath, "characters");

  static String get charactersRegistryPath => p.join(runtimeCharactersPath, "registry.json");

  static String runtimeCharacterPath(String characterId) =>
      p.join(runtimeCharactersPath, "$characterId.json");

  // announcements/
  static String get runtimeAnnouncementsPath => p.join(runtimeDataPath, "announcements");

  static String get announcementsIndexPath => p.join(runtimeAnnouncementsPath, "index.json");

  static String announcementFilePath(String locale, String id) =>
      p.join(runtimeAnnouncementsPath, "files", locale, id);

  static String announcementRegistryPath(String id) =>
      p.join(runtimeAnnouncementsPath, "registry", "$id.json");
}
