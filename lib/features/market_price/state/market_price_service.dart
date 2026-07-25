import "package:eve_fit_assistant/features/market_price/models/models.dart";
import "package:eve_fit_assistant/features/market_price/remote/remote.dart";
import "package:eve_fit_assistant/features/market_price/state/price_worker_pool.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "market_price_service.g.dart";

/// Market server resolved for price lookups.
///
/// The active checkout's snapshot metadata (`marketServer`) takes precedence.
/// When the snapshot declares no market server, the user's
/// [AppSetting.marketServerFallback] is used instead. Returns `null` —
/// disabling the feature — when neither yields a known server.
@riverpodSingleton
MarketServer? marketPriceServer(Ref ref) {
  final activeOpt = ref.watch(activeCheckoutProvider);
  if (activeOpt.isSome()) {
    final snapshotHash = activeOpt.toNullable()!.resourceSnapshotHash;
    if (snapshotHash.isNotEmpty) {
      final metaOpt = ref.watch(assetStoreProvider).readResourceSnapshotMetaSync(snapshotHash);
      if (metaOpt.isSome()) {
        final server = MarketServer.parse(metaOpt.toNullable()!.marketServer);
        if (server != null) return server;
      }
    }
  }

  return MarketServer.parse(ref.watch(appSettingServiceProvider).marketServerFallback);
}

/// Shared worker pool for price fetches, or `null` when the feature is
/// disabled for the active checkout.
@riverpodSingleton
PriceWorkerPool? marketPriceWorkerPool(Ref ref) {
  final server = ref.watch(marketPriceServerProvider);
  if (server == null) return null;

  final client = MarketPriceClient(server: server);
  ref.onDispose(client.dispose);
  return PriceWorkerPool(fetcher: client.fetchPrice);
}

/// Enumerates the distinct typeIDs of a fit with their total quantities.
///
/// Includes the hull, all fitted modules and charges, drones, fighters,
/// implants, and boosters. Dynamic (mutated) items resolve to their resulting
/// typeID via the fit's dynamic registry; unresolvable entries are skipped.
Map<int, int> collectFitTypeQuantities(FitStorage fit) {
  final quantities = <int, int>{};

  void add(int typeId, [int count = 1]) => quantities[typeId] = (quantities[typeId] ?? 0) + count;

  int? resolve(FitStorageItemId itemId) => itemId.when(
    item: (id) => id,
    dynamic: (dynamicId) => fit.dynamicRegistry.dynamicItems[dynamicId]?.typeId,
  );

  add(fit.body.shipTypeId);

  for (final slotList in [
    fit.body.slots.high,
    fit.body.slots.medium,
    fit.body.slots.low,
    fit.body.slots.rig,
    fit.body.slots.subsystem,
    fit.body.slots.service,
  ]) {
    for (final slotOpt in slotList) {
      slotOpt.match(() {}, (module) {
        final typeId = resolve(module.itemId);
        if (typeId != null) add(typeId);
        module.charge.match(() {}, (charge) => add(charge.typeId));
      });
    }
  }

  for (final drone in fit.body.drones) {
    final typeId = resolve(drone.itemId);
    if (typeId != null) add(typeId, drone.quantity);
  }
  for (final fighter in fit.body.fighters) {
    final typeId = resolve(fighter.itemId);
    if (typeId != null) add(typeId, fighter.quantity);
  }
  for (final implant in fit.body.implants) {
    final typeId = resolve(implant.itemId);
    if (typeId != null) add(typeId);
  }
  for (final booster in fit.body.boosters) {
    final typeId = resolve(booster.itemId);
    if (typeId != null) add(typeId);
  }

  return quantities;
}

/// Estimated total price for a fit.
///
/// Completes only after every requested type has resolved (priced or failed),
/// so consumers can omit the UI until the figure is final. Returns `null`
/// when the feature is disabled, the fit is unavailable, or no type yielded a
/// price. Types without a price are silently excluded from the total.
@riverpod
Future<FitPriceSummary?> fitEstimatedPrice(Ref ref, String fitId) async {
  final pool = ref.watch(marketPriceWorkerPoolProvider);
  if (pool == null) return null;

  final fitState = ref.watch(fitProvider(fitId));
  if (!fitState.isInitialized) return null;

  final quantities = collectFitTypeQuantities(fitState.fit);
  if (quantities.isEmpty) return null;

  final entries = quantities.entries.toList();
  final prices = await Future.wait(entries.map((entry) => pool.request(typeId: entry.key)));

  double total = 0;
  var pricedCount = 0;
  var unpricedCount = 0;
  for (final (index, price) in prices.indexed) {
    if (price == null) {
      unpricedCount++;
      continue;
    }
    total += price * entries[index].value;
    pricedCount++;
  }
  if (pricedCount == 0) return null;

  return FitPriceSummary(
    total: total,
    pricedTypeCount: pricedCount,
    unpricedTypeCount: unpricedCount,
  );
}
