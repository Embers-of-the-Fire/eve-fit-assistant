import "dart:async";
import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/repo/models/active.dart";
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

/// Manages active.json read and write operations.
class ActiveService {
  ActiveService();

  final _Mutex _activeMutex = _Mutex();

  final _changeController = StreamController<Active>.broadcast();

  /// A stream that emits the latest [Active] value whenever `active.json` is written
  /// via [writeActive]. This allows Riverpod providers to react to changes without
  /// polling.
  Stream<Active> get watch => _changeController.stream;

  /// Reads active.json and returns [Some] with the parsed [Active], or [None] if the
  /// file is missing or unreadable.
  Option<Active> readActive() {
    final file = File(RepoPaths.activePath);
    if (!file.existsSync()) return const None();
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return Some(Active.fromJson(json));
    } on Exception catch (e, stackTrace) {
      warning("Failed to read active.json", stackTrace: stackTrace);
      return const None();
    }
  }

  /// Writes [active] to active.json atomically via write-to-temp-then-rename.
  ///
  /// The write is guarded by a mutex to serialize concurrent write attempts.
  /// After the write completes, the [watch] stream emits the new [active] value.
  Future<void> writeActive(Active active) => _activeMutex.synchronized(() async {
    final path = RepoPaths.activePath;
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    File("$path.tmp")
      ..writeAsStringSync(jsonEncode(active.toJson()), flush: true)
      ..renameSync(path);
    _changeController.add(active);
  });

  /// Returns the active branch ID if [readActive] succeeds and `branchId` is non-null.
  Option<String> getActiveBranchId() =>
      readActive().flatMap((a) => Option.fromNullable(a.branchId));

  /// Returns the active checkout ID if [readActive] succeeds.
  Option<String> getActiveCheckoutId() => readActive().map((a) => a.checkoutId);

  /// Returns `true` when the active record is missing or has `branchId == null`,
  /// meaning the app is in detached mode. Update and revert operations are
  /// unavailable in this state because there is no reflog to track history.
  bool get isDetached => readActive().map((a) => a.branchId == null).getOrElse(() => true);

  /// Convenience guard for mutation operations (update, revert).
  ///
  /// Returns [Some] with an error message when [isDetached] is `true`, or [None]
  /// when the operation is allowed. Callers can use the message to present a
  /// dialog suggesting the user attach to a branch first.
  Option<String> guardMutate() =>
      isDetached ? const Some("Detached mode: attach to a branch first.") : const None();
}
