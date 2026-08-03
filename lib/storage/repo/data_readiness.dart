import "dart:async";

import "package:eve_fit_assistant/compat/isolate.dart";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:flutter/foundation.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "data_readiness.freezed.dart";
part "data_readiness.g.dart";

@freezed
sealed class DataReadinessState with _$DataReadinessState {
  const factory DataReadinessState.idle() = DataReadinessIdle;
  const factory DataReadinessState.loading() = DataReadinessLoading;
  const factory DataReadinessState.ready() = DataReadinessReady;
  const factory DataReadinessState.error({required String message}) = DataReadinessError;
}

/// Composite readiness level derived from collection + engine states.
enum DataReadinessLevel {
  /// No active checkout or data not yet requested.
  idle,

  /// Collection is being decoded (app is interactive, skeletons shown).
  collectionLoading,

  /// Collection ready, engine still initializing.
  collectionReady,

  /// Both collection and engine are ready.
  fullyReady,

  /// A recoverable error occurred during loading.
  error,
}

/// Orchestrates non-blocking data loading with guaranteed workflow dispatch.
///
/// Responsibilities:
/// - Decodes [RepoCollectionService] off the main isolate.
/// - Tracks composite readiness (collection + engine).
/// - Cancels in-flight decode on checkout switch (generation guard).
/// - Seeds the synchronous [repoCollectionProvider] once decode completes.
@riverpodSingleton
class DataReadinessNotifier extends _$DataReadinessNotifier {
  int _generation = 0;
  RepoCollectionService? _decodedCollection;
  ResourceBlobProxy? _activeProxy;
  bool _decodeInFlight = false;

  @override
  DataReadinessState build() {
    final proxy = ref.watch(resourceBlobProxyProvider).value;
    ref.watch(nativeFitEngineServiceProvider);

    if (!identical(proxy, _activeProxy)) {
      _activeProxy = proxy;
      _decodedCollection = null;
      _decodeInFlight = false;
      _generation++;
    }

    if (proxy == null) {
      return const DataReadinessState.idle();
    }

    if (_decodedCollection != null) {
      return const DataReadinessState.ready();
    }

    if (!_decodeInFlight) {
      _decodeInFlight = true;
      unawaited(_dispatchDecode(proxy));
    }
    return const DataReadinessState.loading();
  }

  /// Composite readiness level for UI consumption.
  DataReadinessLevel get level {
    final readiness = state;
    if (readiness is DataReadinessError) return DataReadinessLevel.error;
    if (readiness is DataReadinessIdle) return DataReadinessLevel.idle;

    final collectionReady = _decodedCollection != null;
    if (!collectionReady) return DataReadinessLevel.collectionLoading;

    final engineState = ref.read(nativeFitEngineServiceProvider);
    if (engineState.engineOrNull != null) {
      return DataReadinessLevel.fullyReady;
    }
    return DataReadinessLevel.collectionReady;
  }

  Future<void> _dispatchDecode(ResourceBlobProxy proxy) async {
    final generation = ++_generation;
    state = const DataReadinessState.loading();

    try {
      final collection = await _decodeInIsolate(proxy);
      if (generation != _generation || !ref.mounted) return;

      _decodedCollection = collection;
      _decodeInFlight = false;
      state = const DataReadinessState.ready();
    } on Object catch (e, st) {
      if (generation != _generation || !ref.mounted) return;
      _decodeInFlight = false;
      debug("DataReadiness: collection decode failed: $e", stackTrace: st);
      state = DataReadinessState.error(message: e.toString());
    }
  }

  Future<RepoCollectionService> _decodeInIsolate(ResourceBlobProxy proxy) async {
    if (kIsWeb) {
      // Web: blobs live in OPFS — read bytes through the blob store, then
      // decode (the isolate stub runs this inline on the main event loop).
      final collectionBytes = (await proxy.read("resource://static/collection.pb2")).toNullable();
      if (collectionBytes == null) {
        return Future.error(StateError("collection.pb2 not found in resource index"));
      }

      final localizationBytes = <String, Uint8List>{};
      for (final locale in ["en", "zh"]) {
        final bytes = (await proxy.read(
          "resource://localization/localization_$locale.pb2",
        )).toNullable();
        if (bytes != null) localizationBytes[locale] = bytes;
      }

      return Isolate.run(
        () => RepoCollectionService.decodeFromBytes(
          collectionBytes: collectionBytes,
          localizationBytes: localizationBytes,
        ),
      );
    }

    // Native: resolve content-addressed paths and read inside the background
    // isolate so large files never transit the main isolate.
    final collectionPath = proxy.resolvePath("resource://static/collection.pb2");
    if (collectionPath == null) {
      return Future.error(StateError("collection.pb2 not found in resource index"));
    }

    final localizationPaths = <String, String>{};
    for (final locale in ["en", "zh"]) {
      final path = proxy.resolvePath("resource://localization/localization_$locale.pb2");
      if (path != null) localizationPaths[locale] = path;
    }

    return Isolate.run(
      () => RepoCollectionService.decodeFromPaths(
        collectionPath: collectionPath,
        localizationPaths: localizationPaths,
      ),
    );
  }

  /// Exposes the decoded collection for the synchronous provider to consume.
  RepoCollectionService? get decodedCollection => _decodedCollection;

  /// Forces a retry after an error state.
  void retry() {
    final proxy = ref.read(resourceBlobProxyProvider).value;
    if (proxy == null) return;
    _decodedCollection = null;
    _decodeInFlight = true;
    unawaited(_dispatchDecode(proxy));
  }
}
