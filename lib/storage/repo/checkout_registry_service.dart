import "dart:async";
import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_registry.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
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

/// Manages the checkout registry (checkouts/checkouts.json) read and write operations.
///
/// Replaces the old ActiveService. The registry tracks all checkouts and the
/// currently active one via activeCheckoutId.
class CheckoutRegistryService {
  CheckoutRegistryService();

  final _Mutex _mutex = _Mutex();

  final _changeController = StreamController<CheckoutRegistry>.broadcast();

  /// A stream that emits the latest [CheckoutRegistry] whenever
  /// checkouts.json is written.
  Stream<CheckoutRegistry> get watch => _changeController.stream;

  /// Reads checkouts.json and returns [Some] with the parsed [CheckoutRegistry],
  /// or [None] if the file is missing or unreadable.
  Option<CheckoutRegistry> readRegistry() {
    final file = File(RepoPaths.checkoutRegistryPath);
    if (!file.existsSync()) return const None();
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return Some(CheckoutRegistry.fromJson(json));
    } on Exception catch (e, stackTrace) {
      warning("Failed to read checkout registry", stackTrace: stackTrace);
      return const None();
    }
  }

  /// Writes [registry] to checkouts.json atomically.
  ///
  /// The write is guarded by a mutex. After the write completes, the [watch]
  /// stream emits the new value.
  Future<void> writeRegistry(CheckoutRegistry registry) => _mutex.synchronized(() async {
    final path = RepoPaths.checkoutRegistryPath;
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    File("$path.tmp")
      ..writeAsStringSync(jsonEncode(registry.toJson()), flush: true)
      ..renameSync(path);
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

  /// Returns `true` when no registry file exists or no active checkout is set.
  bool get hasNoSetup =>
      readRegistry().map((r) => r.activeCheckoutId == null).getOrElse(() => true);
}
