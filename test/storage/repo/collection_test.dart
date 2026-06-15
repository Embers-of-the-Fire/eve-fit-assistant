import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/data/proto/collections.pb.dart";
import "package:eve_fit_assistant/data/proto/fit.pb.dart";
import "package:eve_fit_assistant/data/proto/groups.pb.dart";
import "package:eve_fit_assistant/data/proto/localizations.pb.dart";
import "package:eve_fit_assistant/data/proto/types.pb.dart" as pb_types;
import "package:eve_fit_assistant/data/proto/utils.pb.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/models/active.dart";
import "package:eve_fit_assistant/storage/repo/models/asset_manifest.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;
import "package:riverpod/riverpod.dart";

AppSetting testAppSetting() => AppSetting(
  locale: Locale.en,
  enableDebugLog: false,
  shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
  showCheckoutImpactWarnings: true,
  typeListReturnBehavior: TypeListReturnBehavior.previousPage,
  remoteContent: const RemoteContentSetting(originUrl: "https://example.com"),
);

void main() {
  late String tempDir;
  late ProviderContainer container;
  late String savedDocumentsPath;
  late String savedTempPath;

  setUp(() {
    try {
      savedDocumentsPath = PathProvider.documentsPath;
      savedTempPath = PathProvider.tempPath;
    } catch (_) {
      savedDocumentsPath = "";
      savedTempPath = "";
    }
    tempDir = Directory.systemTemp.createTempSync("efa_collection_test_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.tempPath = p.join(tempDir, "tmp");
    Directory(p.join(tempDir, "tmp")).createSync(recursive: true);

    final setting = testAppSetting();
    container = ProviderContainer(
      overrides: [appSettingServiceProvider.overrideWithValue(setting)],
    );
    addTearDown(container.dispose);
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    PathProvider.documentsPath = savedDocumentsPath;
    PathProvider.tempPath = savedTempPath;
  });

  group("repoCollectionProvider", () {
    test("returns null when no checkout is active", () {
      final result = container.read(repoCollectionProvider);
      expect(result, isNull);
    });

    test("returns null when active checkout has empty checkoutId", () async {
      final active = Active(
        schemaVersion: 2,
        checkoutId: "",
        activatedAt: "2024-01-15T10:30:00Z",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX"),
      );
      final activeFile = File(RepoPaths.activePath);
      if (!activeFile.parent.existsSync()) activeFile.parent.createSync(recursive: true);
      activeFile.writeAsStringSync(jsonEncode(active.toJson()), flush: true);

      final result = container.read(repoCollectionProvider);
      expect(result, isNull);
    });

    test("returns a populated RepoCollectionService when a checkout is active", () {
      _setupCheckout(tempDir);

      final result = container.read(repoCollectionProvider);
      expect(result, isNotNull);
      expect(result, isA<RepoCollectionService>());
    });
  });

  group("RepoCollectionService queries", () {
    setUp(() {
      _setupCheckout(tempDir);
    });

    test("getShip returns a valid Ship for known IDs", () {
      final collection = container.read(repoCollectionProvider)!;

      final ship = collection.getShip(1);
      expect(ship, isNotNull);
      expect(ship!.typeId, 1);
    });

    test("getShip returns null for unknown IDs", () {
      final collection = container.read(repoCollectionProvider)!;

      expect(collection.getShip(999), isNull);
    });

    test("getType returns a valid Type for known IDs", () {
      final collection = container.read(repoCollectionProvider)!;

      final type = collection.getType(1);
      expect(type, isNotNull);
      expect(type!.typeId, 1);
    });

    test("getType returns null for unknown IDs", () {
      final collection = container.read(repoCollectionProvider)!;

      expect(collection.getType(999), isNull);
    });

    test("getAllTypes returns all type entries", () {
      final collection = container.read(repoCollectionProvider)!;

      final allTypes = collection.getAllTypes();
      expect(allTypes.length, 1);
      expect(allTypes.first.typeId, 1);
    });

    test("getSkillTypeIds returns skill type IDs derived from groups", () {
      final collection = container.read(repoCollectionProvider)!;

      final skillIds = collection.getSkillTypeIds();
      expect(skillIds, contains(1));
    });

    test("getSkillProfile returns correct skill map for known profiles", () {
      final collection = container.read(repoCollectionProvider)!;

      final profile = collection.getSkillProfile("test_profile");
      expect(profile, isNotNull);
      expect(profile![1], 5);
    });

    test("getSkillProfile returns null for unknown profiles", () {
      final collection = container.read(repoCollectionProvider)!;

      expect(collection.getSkillProfile("nonexistent"), isNull);
    });

    test("getLocalizedName returns localized string for valid locale and key", () {
      final collection = container.read(repoCollectionProvider)!;

      expect(collection.getLocalizedName(100, "en"), "Test Name");
    });

    test("getLocalizedName returns empty string for missing locale", () {
      final collection = container.read(repoCollectionProvider)!;

      expect(collection.getLocalizedName(100, "fr"), "");
    });

    test("getLocalizedName returns empty string for missing key", () {
      final collection = container.read(repoCollectionProvider)!;

      expect(collection.getLocalizedName(999, "en"), "");
    });

    test("getIconPath returns icon path string for types with icon data", () {
      final collection = container.read(repoCollectionProvider)!;

      final path = collection.getIconPath(1, 64);
      expect(path, isNotEmpty);
      expect(path, contains("icons"));
    });

    test("getIconPath returns empty string for types without icon data", () {
      final collection = container.read(repoCollectionProvider)!;

      final path = collection.getIconPath(999, 64);
      expect(path, "");
    });

    test("slots returns a Slots object", () {
      final collection = container.read(repoCollectionProvider)!;

      final slots = collection.slots;
      expect(slots, isNotNull);
      expect(slots, isA<Slots>());
    });
  });
}

/// Creates a minimal active checkout on disk so that [repoCollectionProvider]
/// successfully builds a [RepoCollectionService].
void _setupCheckout(String tempDir) {
  // ── 1. Build a minimal Collection protobuf ──
  final collection = Collection();
  collection.slots = Slots();

  // Type with icon_id = 42 and type_name id = 100
  final type = pb_types.Type()
    ..typeId = 1
    ..groupId = 2
    ..typeName = (LocalizationID()..id = 100)
    ..icon = (Icon()..iconId = 42);
  collection.types[1] = type;

  // Ship
  final ship = Ship()..typeId = 1;
  collection.ships[1] = ship;

  // Group with skill category (16 = EveConstCategoryId.skill)
  final group = Group()
    ..groupId = 2
    ..categoryId = 16
    ..groupName = (LocalizationID()..id = 200);
  collection.groups[2] = group;

  // Skill profile
  final skillProfile = Collection_SkillProfile();
  skillProfile.skills[1] = 5;
  collection.skillProfiles["test_profile"] = skillProfile;

  final collectionBytes = Uint8List.fromList(collection.writeToBuffer());

  // ── 2. Build a minimal Localization protobuf ──
  final enLoc = Localization()
    ..language = LocalizationLanguage.EN
    ..localizedStrings[100] = "Test Name";
  final enLocBytes = Uint8List.fromList(enLoc.writeToBuffer());

  // ── 3. Compute hashes and write to asset store ──
  final collectionPathHash = RepoHash.hashPath("static/collection.pb2");
  final collectionContentHash = RepoHash.hashContent(collectionBytes);
  final collectionAssetPath = RepoPaths.assetPath(collectionPathHash, collectionContentHash);
  final collectionAssetFile = File(collectionAssetPath);
  if (!collectionAssetFile.parent.existsSync()) {
    collectionAssetFile.parent.createSync(recursive: true);
  }
  collectionAssetFile.writeAsBytesSync(collectionBytes, flush: true);

  final enLocPathHash = RepoHash.hashPath("localization/localization_en.pb2");
  final enLocContentHash = RepoHash.hashContent(enLocBytes);
  final enLocAssetPath = RepoPaths.assetPath(enLocPathHash, enLocContentHash);
  final enLocAssetFile = File(enLocAssetPath);
  if (!enLocAssetFile.parent.existsSync()) {
    enLocAssetFile.parent.createSync(recursive: true);
  }
  enLocAssetFile.writeAsBytesSync(enLocBytes, flush: true);

  // ── 4. Build asset manifest ──
  final checkoutId = "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef";
  final manifest = AssetManifest(
    assetsVersion: 1,
    files: IMap({
      "static/collection.pb2": AssetFile(
        pathHash: collectionPathHash,
        hash: collectionContentHash,
        size: collectionBytes.length,
      ),
      "localization/localization_en.pb2": AssetFile(
        pathHash: enLocPathHash,
        hash: enLocContentHash,
        size: enLocBytes.length,
      ),
      "static/images/icons/42.png": AssetFile(
        pathHash: RepoHash.hashPath("static/images/icons/42.png"),
        hash: RepoHash.hashString("placeholder"),
        size: 0,
      ),
    }),
  );

  // ── 5. Write manifest ──
  final manifestPath = RepoPaths.checkoutManifestPath(checkoutId);
  final manifestFile = File(manifestPath);
  if (!manifestFile.parent.existsSync()) manifestFile.parent.createSync(recursive: true);
  manifestFile.writeAsStringSync(jsonEncode(manifest.toJson()), flush: true);

  // ── 6. Write active.json ──
  final active = Active(
    schemaVersion: 2,
    checkoutId: checkoutId,
    activatedAt: "2024-01-15T10:30:00Z",
    serverId: "serenity",
    metadata: GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX"),
  );
  final activeFile = File(RepoPaths.activePath);
  if (!activeFile.parent.existsSync()) activeFile.parent.createSync(recursive: true);
  activeFile.writeAsStringSync(jsonEncode(active.toJson()), flush: true);
}
