import "dart:async";
import "dart:convert";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/fs/doc_store.dart";
import "package:eve_fit_assistant/storage/fs/user_store.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_registry.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fpdart/fpdart.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";
import "package:uuid/uuid.dart";

part "manager.g.dart";

/// Fit storage is always under global control,
/// So there's no need to maintain a global singleton outside of the Ref tree.
@riverpodSingleton
class FitRegistryManager extends _$FitRegistryManager {
  static const _registryKey = "registry.json";

  DocStore? _store;
  Future<void> _pendingSync = Future<void>.value();

  Future<DocStore> get _storeReady async {
    var store = _store;
    if (store == null) {
      store = createUserDocStore(UserDataDomain.fittings);
      await store.init();
      _store = store;
    }
    return store;
  }

  @override
  FitRegistry build() {
    unawaited(_loadRegistry());
    return FitRegistry(fits: IMap());
  }

  Future<void> _loadRegistry() async {
    final store = await _storeReady;
    final text = await store.read(_registryKey);
    final FitRegistry registry;
    if (text == null) {
      registry = FitRegistry(fits: IMap());
      await store.write(_registryKey, jsonEncode(encodeFitRegistry(registry)));
    } else {
      final decoded = decodeFitRegistry(jsonDecode(text) as Map<String, dynamic>);
      registry = decoded.registry;
      if (decoded.didMigrate) {
        await store.write(_registryKey, jsonEncode(encodeFitRegistry(registry)));
      }
    }
    if (!ref.mounted) return;
    state = registry;
  }

  void updateFit(FitMetadata metadata) {
    debug(
      "Update fit ${metadata.fitId} ${metadata.shipTypeId} checkout ${metadata.checkoutRef.checkoutId}",
    );
    state = state.copyWith(fits: state.fits.add(metadata.fitId, metadata));
    _syncToStore();
  }

  void _syncToStore() {
    final registry = state;
    _pendingSync = _pendingSync.catchError((Object _, StackTrace _) {}).then((_) async {
      final store = await _storeReady;
      await store.write(_registryKey, jsonEncode(encodeFitRegistry(registry)));
    });
  }
}

@riverpod
Iterable<FitMetadata> fitsForShip(Ref ref, int shipId) =>
    ref.watch(fitRegistryManagerProvider).fits.values.filter((t) => t.shipTypeId == shipId);

/// Shared fittings document store (files on native, IndexedDB on web).
@riverpodSingleton
DocStore fitsDocStore(Ref ref) => createUserDocStore(UserDataDomain.fittings);

@riverpodSingleton
class FitManager extends _$FitManager {
  static const _idGenerator = Uuid();

  @override
  Future<DateTime> build() async {
    ref.read(fitRegistryManagerProvider);
    return DateTime.now();
  }

  static String generateFitId() => _idGenerator.v4();

  CheckoutRef _checkoutRefForActive(Option<CheckoutRegistryEntry> entryOpt) =>
      entryOpt.match(() => throw StateError("A valid checkout must be active."), (entry) {
        final checkoutId = ref
            .read(activeCheckoutIdProvider)
            .match(() => throw StateError("A valid checkout must be active."), (id) => id);
        return CheckoutRef(checkoutId: checkoutId, serverId: entry.serverId);
      });

  Future<FitMetadata> newFit(int shipId, String name, {String? description}) async {
    final ship = ref.watch(repoCollectionProvider.select((c) => c?.getShip(shipId)));
    if (ship == null) {
      final text = "Ship with ID $shipId not found in repo collection.";
      error(text);
      throw Exception(text);
    }
    info("Creating new fit of type $shipId named $name");
    final fitId = generateFitId();
    final active = ref.watch(activeCheckoutProvider);
    final metadata = FitMetadata(
      fitId: fitId,
      shipTypeId: shipId,
      name: name,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      description: description ?? "",
      checkoutRef: _checkoutRefForActive(active),
    );
    final fit = FitStorage.empty(metadata, ship);
    final store = ref.read(fitsDocStoreProvider);
    await store.write("${fit.metadata.fitId}.json", jsonEncode(encodeFitStorage(fit)));
    ref.read(fitRegistryManagerProvider.notifier).updateFit(metadata);
    return metadata;
  }

  Future<void> deleteFit(String fitId) async {
    final registry = ref.read(fitRegistryManagerProvider);
    final metadata = registry.fits[fitId];
    if (metadata == null) {
      final text = "Fit with ID $fitId not found in registry.";
      error(text);
      throw Exception(text);
    }
    final store = ref.read(fitsDocStoreProvider);
    if (await store.exists("$fitId.json")) {
      await store.delete("$fitId.json");
      info("Deleted fit $fitId");
    } else {
      warning("Fit $fitId does not exist.");
    }
    final notifier = ref.read(fitRegistryManagerProvider.notifier);
    notifier
      ..state = notifier.state.copyWith(fits: notifier.state.fits.remove(fitId))
      .._syncToStore();
  }

  Future<FitMetadata> importFit(FitStorage importedFit) async {
    final ship = ref.watch(
      repoCollectionProvider.select((c) => c?.getShip(importedFit.body.shipTypeId)),
    );
    if (ship == null) {
      final text = "Ship with ID ${importedFit.body.shipTypeId} not found in repo collection.";
      error(text);
      throw Exception(text);
    }

    final active = ref.watch(activeCheckoutProvider);
    final fitId = generateFitId();
    final metadata = importedFit.metadata.copyWith(
      fitId: fitId,
      shipTypeId: importedFit.body.shipTypeId,
      name: importedFit.metadata.name.trim().isEmpty
          ? "Imported Fit"
          : importedFit.metadata.name.trim(),
      lastModified: DateTime.now().millisecondsSinceEpoch,
      checkoutRef: _checkoutRefForActive(active),
    );
    final fit = pruneDynamicRegistry(importedFit.copyWith(metadata: metadata));

    final store = ref.read(fitsDocStoreProvider);
    await store.write("${fit.metadata.fitId}.json", jsonEncode(encodeFitStorage(fit)));
    ref.read(fitRegistryManagerProvider.notifier).updateFit(metadata);
    return metadata;
  }
}
