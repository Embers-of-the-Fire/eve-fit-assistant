import "dart:async";
import "dart:convert";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/fs/blob_store.dart";
import "package:eve_fit_assistant/storage/fs/memory_blob_store.dart";
import "package:eve_fit_assistant/storage/fs/repo_store.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_registry.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:flutter/foundation.dart";
import "package:fpdart/fpdart.dart";

/// Simple Future-based mutex for serializing write operations.
class _Mutex {
  Future<void> _last = Future.value();

  Future<T> synchronized<T>(Future<T> Function() fn) {
    final prev = _last;
    final next = prev.then((_) => fn());
    _last = next.then((_) => null, onError: (_) => null);
    return next;
  }
}

/// State of the `checkouts.json` backing file as observed by the last load.
enum RegistryFileState {
  /// `load` has not run yet.
  unknown,

  /// The file does not exist (first launch).
  missing,

  /// The file exists and parsed successfully.
  ok,

  /// The file exists but could not be parsed.
  corrupt,
}

/// Manages the checkout registry (checkouts/checkouts.json) read and write
/// operations.
///
/// Reads are served synchronously from a write-through in-memory cache that
/// is populated by [load] during startup. Writes update the cache immediately
/// and persist asynchronously (mutex-guarded), so callers observe new values
/// without waiting for storage I/O. This keeps the registry — a tiny JSON
/// document — readable from synchronous UI providers while the underlying
/// store may be async-only (OPFS on web).
class CheckoutRegistryService {
  CheckoutRegistryService([BlobStore? store])
    : _store = store ?? createRepoBlobStore(),
      _fileState = RegistryFileState.unknown;

  /// Creates a service with [registry] already loaded into the cache.
  ///
  /// Test-only: avoids async storage I/O (which does not complete under
  /// widget-test `FakeAsync`) while keeping the synchronous read contract.
  @visibleForTesting
  CheckoutRegistryService.seeded(CheckoutRegistry registry, {BlobStore? store})
    : _store = store ?? MemoryBlobStore(),
      _cache = registry,
      _fileState = RegistryFileState.ok;

  final BlobStore _store;

  final _Mutex _mutex = _Mutex();

  final _changeController = StreamController<CheckoutRegistry>.broadcast();

  CheckoutRegistry? _cache;
  RegistryFileState _fileState;
  Future<void>? _loadInFlight;

  /// Number of writes started so far. A load that began before a write must
  /// not clobber the newer in-memory registry that write installed.
  int _writeGeneration = 0;

  /// State of the backing file as of the last [load].
  RegistryFileState get fileState => _fileState;

  /// A stream that emits the latest [CheckoutRegistry] whenever
  /// checkouts.json is written or loaded.
  Stream<CheckoutRegistry> get watch => _changeController.stream;

  /// Loads the registry from storage into the in-memory cache and emits it on
  /// [watch] when present.
  ///
  /// Await this once during startup when you need to distinguish "missing"
  /// (first launch) from "corrupt" (present but unparseable) via [fileState]
  /// before proceeding. Reads via [readRegistry] are otherwise self-serving:
  /// the first read lazily triggers a load and subsequent reads return the
  /// populated cache.
  Future<void> load() => _loadInFlight ??= _doLoad();

  Future<void> _doLoad() async {
    final generation = _writeGeneration;
    CheckoutRegistry? cache;
    RegistryFileState state;
    final bytes = await _store.read(RepoPaths.checkoutRegistryPath);
    if (bytes == null) {
      state = RegistryFileState.missing;
    } else {
      try {
        cache = CheckoutRegistry.fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
        state = RegistryFileState.ok;
      } on Exception catch (e, stackTrace) {
        warning("Failed to read checkout registry", stackTrace: stackTrace);
        state = RegistryFileState.corrupt;
      }
    }
    if (generation != _writeGeneration) {
      // A write landed while the read was in flight; the newer in-memory
      // registry installed by that write wins over the stale disk contents.
      return;
    }
    _cache = cache;
    _fileState = state;
    if (cache != null) _changeController.add(cache);
  }

  /// Reads the cached registry, or [None] if absent.
  ///
  /// The first call lazily kicks off the async [load]; the result becomes
  /// visible on a later read (and is pushed to [watch] listeners).
  Option<CheckoutRegistry> readRegistry() {
    if (_fileState == RegistryFileState.unknown) {
      unawaited(load());
    }
    return Option.fromNullable(_cache);
  }

  /// Writes [registry] to the cache and persists it to checkouts.json.
  ///
  /// The persist is guarded by a mutex. After the write completes, the [watch]
  /// stream emits the new value.
  Future<void> writeRegistry(CheckoutRegistry registry) => _mutex.synchronized(() async {
    _writeGeneration++;
    _cache = registry;
    _fileState = RegistryFileState.ok;
    await _store.write(
      RepoPaths.checkoutRegistryPath,
      Uint8List.fromList(utf8.encode(jsonEncode(registry.toJson()))),
    );
    _changeController.add(registry);
  });

  /// Creates an empty registry if none exists, writes it, and emits it.
  Future<CheckoutRegistry> ensureRegistry() async {
    final existing = readRegistry();
    if (existing.isSome()) return existing.toNullable()!;
    const registry = CheckoutRegistry(schemaVersion: 1);
    await writeRegistry(registry);
    return registry;
  }

  /// Returns the active checkout UUID, or [None] if unset.
  Option<String> activeCheckoutId() =>
      readRegistry().flatMap((r) => Option.fromNullable(r.activeCheckoutId));

  /// Returns the active checkout entry, or [None].
  Option<CheckoutRegistryEntry> activeCheckoutEntry() => readRegistry().flatMap((r) {
    final id = r.activeCheckoutId;
    if (id == null) return const None();
    return Option.fromNullable(r.checkouts[id]);
  });

  /// Returns `true` when no active checkout is set (detached mode).
  bool get isDetached => activeCheckoutId().isNone();

  /// Sets the active checkout to [checkoutId].
  Future<void> setActiveCheckout(String checkoutId) async {
    final registry = readRegistry().getOrElse(() => const CheckoutRegistry(schemaVersion: 1));
    await writeRegistry(registry.copyWith(activeCheckoutId: checkoutId));
  }

  /// Clears the active checkout (detach mode).
  Future<void> clearActiveCheckout() async {
    final registry = readRegistry();
    if (registry.isNone()) return;
    await writeRegistry(registry.toNullable()!.copyWith(activeCheckoutId: null));
  }

  /// Adds a checkout entry to the registry.
  ///
  /// If [setActive] is true (default for first checkout), also sets it as active.
  Future<void> addCheckout({
    required String checkoutId,
    required CheckoutRegistryEntry entry,
    bool setActive = true,
  }) async {
    final registry = readRegistry().getOrElse(() => const CheckoutRegistry(schemaVersion: 1));
    final updated = registry.copyWith(
      checkouts: registry.checkouts.add(checkoutId, entry),
      activeCheckoutId: setActive ? checkoutId : registry.activeCheckoutId,
    );
    await writeRegistry(updated);
  }

  /// Removes a checkout entry from the registry.
  ///
  /// If the removed checkout was active, clears the active checkout.
  Future<void> removeCheckout(String checkoutId) async {
    final registry = readRegistry();
    if (registry.isNone()) return;
    var updated = registry.toNullable()!.copyWith(
      checkouts: registry.toNullable()!.checkouts.remove(checkoutId),
    );
    if (updated.activeCheckoutId == checkoutId) {
      updated = updated.copyWith(activeCheckoutId: null);
    }
    await writeRegistry(updated);
  }

  /// Returns `true` when no registry exists or no active checkout is set.
  bool get hasNoSetup =>
      readRegistry().map((r) => r.activeCheckoutId == null).getOrElse(() => true);
}
