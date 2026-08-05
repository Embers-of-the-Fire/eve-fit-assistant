import "dart:async";

import "package:eve_fit_assistant/compat/isolate.dart";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/localization_db.dart";
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

    // Warm the localization database in parallel with the collection decode so
    // the first name lookup never pays the open cost (blob copy + worker on
    // web) on the critical path. The provider self-manages its lifecycle across
    // checkout switches, so a stale warm-up here is harmless.
    unawaited(_warmLocalizationDb());

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
      // decode. Web has no isolates, so the decode runs on the main event
      // loop; the chunked decoder yields between chunks to keep the UI
      // responsive and stops early when this generation is superseded.
      final collectionBytes = (await proxy.read("resource://static/collection.pb2")).toNullable();
      if (collectionBytes == null) {
        return Future.error(StateError("collection.pb2 not found in resource index"));
      }

      final generation = _generation;
      return RepoCollectionService.decodeFromBytesChunked(
        collectionBytes: collectionBytes,
        isCancelled: () => generation != _generation || !ref.mounted,
      );
    }

    // Native: resolve the content-addressed path and read inside the
    // background isolate so the large file never transits the main isolate.
    final collectionPath = proxy.resolvePath("resource://static/collection.pb2");
    if (collectionPath == null) {
      return Future.error(StateError("collection.pb2 not found in resource index"));
    }

    return _decodeCollectionFromPath(collectionPath);
  }

  /// Exposes the decoded collection for the synchronous provider to consume.
  RepoCollectionService? get decodedCollection => _decodedCollection;

  /// Opens the localization database ahead of first use.
  ///
  /// Best-effort: failures are logged and never surface to the UI. Once opened
  /// the singleton stays warm for the active checkout; a checkout switch
  /// reopens it through the provider's own dependency tracking.
  Future<void> _warmLocalizationDb() async {
    try {
      await ref.read(localizationDbServiceProvider.future);
    } on Object catch (e, st) {
      debug("DataReadiness: localization db warm-up failed: $e", stackTrace: st);
    }
  }

  /// Forces a retry after an error state.
  void retry() {
    final proxy = ref.read(resourceBlobProxyProvider).value;
    if (proxy == null) return;
    _decodedCollection = null;
    _decodeInFlight = true;
    unawaited(_dispatchDecode(proxy));
  }
}

/// Decodes the collection file in a background isolate.
///
/// Top-level helper so the `Isolate.run()` closure is created in a scope that
/// does not capture the notifier instance — Dart's closure context sharing
/// would otherwise drag the whole Riverpod state into the isolate message.
Future<RepoCollectionService> _decodeCollectionFromPath(String collectionPath) =>
    Isolate.run(() => RepoCollectionService.decodeFromPaths(collectionPath: collectionPath));
