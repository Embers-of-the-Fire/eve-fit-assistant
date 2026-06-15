import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/data/proto/collections.pb.dart";
import "package:eve_fit_assistant/data/proto/fit.pb.dart" as proto_fit;
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/models/active.dart";
import "package:eve_fit_assistant/storage/repo/models/asset_manifest.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:riverpod/riverpod.dart";

const _testMeta = GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX");

Option<Active> _active(String checkoutId, String serverId) => Some(
  Active(
    schemaVersion: 2,
    checkoutId: checkoutId,
    activatedAt: "2024-01-01T00:00:00Z",
    serverId: serverId,
    metadata: _testMeta,
  ),
);

proto_fit.Ship _testShip() => proto_fit.Ship()
  ..typeId = 1234
  ..highSlots = 8
  ..mediumSlots = 5
  ..lowSlots = 6
  ..rigSlots = 3
  ..subsystemSlots = 1
  ..serviceSlots = 0
  ..turretSlots = 8
  ..launcherSlots = 2
  ..fighterTubes = 2;

/// Writes a minimal checkout to disk so that [repoCollectionProvider] builds.
void _setupCheckout(String checkoutId, String tempDir, proto_fit.Ship ship) {
  final collection = Collection();
  collection.slots = proto_fit.Slots();
  collection.ships[ship.typeId] = ship;

  final collectionBytes = Uint8List.fromList(collection.writeToBuffer());

  final collectionPathHash = RepoHash.hashPath("static/collection.pb2");
  final collectionContentHash = RepoHash.hashContent(collectionBytes);
  final collectionAssetPath = RepoPaths.assetPath(collectionPathHash, collectionContentHash);
  final collectionAssetFile = File(collectionAssetPath);
  if (!collectionAssetFile.parent.existsSync())
    collectionAssetFile.parent.createSync(recursive: true);
  collectionAssetFile.writeAsBytesSync(collectionBytes, flush: true);

  final manifest = AssetManifest(
    assetsVersion: 1,
    files: IMap({
      "static/collection.pb2": AssetFile(
        pathHash: collectionPathHash,
        hash: collectionContentHash,
        size: collectionBytes.length,
      ),
      "localization/localization_en.pb2": AssetFile(
        pathHash: RepoHash.hashPath("localization/localization_en.pb2"),
        hash: RepoHash.hashString("placeholder"),
        size: 0,
      ),
    }),
  );

  final manifestPath = RepoPaths.checkoutManifestPath(checkoutId);
  final manifestFile = File(manifestPath);
  if (!manifestFile.parent.existsSync()) manifestFile.parent.createSync(recursive: true);
  manifestFile.writeAsStringSync(jsonEncode(manifest.toJson()), flush: true);
}

late String _tempDir;

ProviderContainer _container({required Option<Active> active, required proto_fit.Ship ship}) {
  if (active.isSome()) {
    _setupCheckout(active.toNullable()!.checkoutId, _tempDir, ship);
  }

  return ProviderContainer(
    overrides: [
      activeCheckoutProvider.overrideWithValue(active),
      appSettingServiceProvider.overrideWithValue(
        AppSetting(
          locale: Locale.en,
          enableDebugLog: false,
          shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
          showCheckoutImpactWarnings: true,
          typeListReturnBehavior: TypeListReturnBehavior.previousPage,
          remoteContent: const RemoteContentSetting(originUrl: "https://example.com"),
        ),
      ),
    ],
  );
}

void main() {
  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_mgr_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  setUp(() {
    _tempDir = Directory.systemTemp.createTempSync("efa_mgr_test_").path;
    PathProvider.documentsPath = _tempDir;
  });

  tearDown(() {
    final dir = Directory(_tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group("newFit", () {
    test("throws StateError when no active checkout", () {
      final container = _container(active: const None(), ship: _testShip());
      addTearDown(container.dispose);

      expect(
        () => container.read(fitManagerProvider.notifier).newFit(1234, "Test"),
        throwsA(isA<Exception>()),
      );
    });

    test("stamps CheckoutRef from active checkout", () async {
      final ship = _testShip();
      final container = _container(active: _active("checkout-abc", "Serenity"), ship: ship);
      addTearDown(container.dispose);

      final metadata = await container.read(fitManagerProvider.notifier).newFit(1234, "Test Fit");

      expect(metadata.checkoutRef.checkoutId, "checkout-abc");
      expect(metadata.checkoutRef.serverId, "Serenity");
      expect(metadata.checkoutRef.metadata, _testMeta);
      expect(metadata.shipTypeId, 1234);
      expect(metadata.name, "Test Fit");
    });
  });

  group("importFit", () {
    test("throws StateError when no active checkout", () {
      final container = _container(active: const None(), ship: _testShip());
      addTearDown(container.dispose);

      final imported = FitStorage.empty(
        const FitMetadata(
          fitId: "import-src",
          shipTypeId: 1234,
          name: "Source Fit",
          lastModified: 0,
          description: "",
          checkoutRef: CheckoutRef(
            checkoutId: "old-checkout",
            serverId: "Serenity",
            metadata: _testMeta,
          ),
        ),
        _testShip(),
      );
      expect(
        () => container.read(fitManagerProvider.notifier).importFit(imported),
        throwsA(isA<Exception>()),
      );
    });

    test("stamps CheckoutRef from active checkout", () async {
      final ship = _testShip();
      final container = _container(active: _active("checkout-xyz", "Serenity"), ship: ship);
      addTearDown(container.dispose);

      final imported = FitStorage.empty(
        const FitMetadata(
          fitId: "import-src",
          shipTypeId: 1234,
          name: "Imported",
          lastModified: 0,
          description: "",
          checkoutRef: CheckoutRef(
            checkoutId: "old-checkout",
            serverId: "Serenity",
            metadata: _testMeta,
          ),
        ),
        ship,
      );
      final metadata = await container.read(fitManagerProvider.notifier).importFit(imported);

      expect(metadata.checkoutRef.checkoutId, "checkout-xyz");
      expect(metadata.checkoutRef.serverId, "Serenity");
    });
  });
}
