import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/data/proto/collections.pb.dart";
import "package:eve_fit_assistant/data/proto/fit.pb.dart" as proto_fit;
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_registry.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:riverpod/riverpod.dart";

Option<CheckoutRegistryEntry> _active(String checkoutId, String serverId) => Some(
  CheckoutRegistryEntry(
    channel: "test-channel",
    serverId: serverId,
    resourceSnapshotHash: "test-snapshot-hash",
    createdAt: "2024-01-01T00:00:00Z",
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

RepoCollectionService _collectionWithShip(proto_fit.Ship ship) {
  final collection = Collection();
  collection.ships[ship.typeId] = ship;
  return RepoCollectionService.forTest(collection: collection);
}

late String _tempDir;

ProviderContainer _container({
  required Option<CheckoutRegistryEntry> active,
  required String activeCheckoutId,
  required proto_fit.Ship ship,
}) {
  final collection = _collectionWithShip(ship);

  return ProviderContainer(
    overrides: [
      activeCheckoutProvider.overrideWithValue(active),
      activeCheckoutIdProvider.overrideWithValue(
        activeCheckoutId.isEmpty ? const None() : Some(activeCheckoutId),
      ),
      repoCollectionProvider.overrideWithValue(collection),
      appSettingServiceProvider.overrideWithValue(
        AppSetting(
          locale: Locale.en,
          enableDebugLog: false,
          shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
          showCheckoutImpactWarnings: true,
          typeListReturnBehavior: TypeListReturnBehavior.previousPage,
          developerMode: false,
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
    PathProvider.appSupportPath = _tempDir;
  });

  tearDown(() {
    final dir = Directory(_tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group("newFit", () {
    test("throws StateError when no active checkout", () {
      final container = _container(active: const None(), activeCheckoutId: "", ship: _testShip());
      addTearDown(container.dispose);

      expect(
        () => container.read(fitManagerProvider.notifier).newFit(1234, "Test"),
        throwsA(isA<StateError>()),
      );
    });

    test("stamps CheckoutRef from active checkout", () async {
      final ship = _testShip();
      final container = _container(
        active: _active("checkout-abc", "Serenity"),
        activeCheckoutId: "checkout-abc",
        ship: ship,
      );
      addTearDown(container.dispose);

      final metadata = await container.read(fitManagerProvider.notifier).newFit(1234, "Test Fit");

      expect(metadata.checkoutRef.checkoutId, "checkout-abc");
      expect(metadata.checkoutRef.serverId, "Serenity");
      expect(metadata.shipTypeId, 1234);
      expect(metadata.name, "Test Fit");
    });
  });

  group("importFit", () {
    test("throws StateError when no active checkout", () {
      final container = _container(active: const None(), activeCheckoutId: "", ship: _testShip());
      addTearDown(container.dispose);

      final imported = FitStorage.empty(
        const FitMetadata(
          fitId: "import-src",
          shipTypeId: 1234,
          name: "Source Fit",
          lastModified: 0,
          description: "",
          checkoutRef: const CheckoutRef(checkoutId: "old-checkout", serverId: "Serenity"),
        ),
        _testShip(),
      );
      expect(
        () => container.read(fitManagerProvider.notifier).importFit(imported),
        throwsA(isA<StateError>()),
      );
    });

    test("stamps CheckoutRef from active checkout", () async {
      final ship = _testShip();
      final container = _container(
        active: _active("checkout-xyz", "Serenity"),
        activeCheckoutId: "checkout-xyz",
        ship: ship,
      );
      addTearDown(container.dispose);

      final imported = FitStorage.empty(
        const FitMetadata(
          fitId: "import-src",
          shipTypeId: 1234,
          name: "Imported",
          lastModified: 0,
          description: "",
          checkoutRef: CheckoutRef(checkoutId: "old-checkout", serverId: "Serenity"),
        ),
        ship,
      );
      final metadata = await container.read(fitManagerProvider.notifier).importFit(imported);

      expect(metadata.checkoutRef.checkoutId, "checkout-xyz");
      expect(metadata.checkoutRef.serverId, "Serenity");
    });
  });
}
