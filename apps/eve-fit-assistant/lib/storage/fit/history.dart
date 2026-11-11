import "dart:math" as math;

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/fit/compatibility.dart";
import "package:eve_fit_assistant/storage/fit/edit_action.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/foundation.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "history.g.dart";

/// Maximum number of states retained per fit for the session.
const int kFitHistoryCapacity = 50;

const CheckoutRef _contentEqualityCheckoutSentinel = CheckoutRef(checkoutId: "", serverId: "");

/// Two committed states are content-equal when they only differ in metadata
/// that the editing contract restamps on every commit, and when their dynamic
/// registries are pruned. History uses this to suppress no-op entries.
bool fitContentEquals(FitStorage left, FitStorage right) =>
    _contentNormalized(left) == _contentNormalized(right);

FitStorage _contentNormalized(FitStorage fit) => pruneDynamicRegistry(
  fit.copyWith(
    metadata: fit.metadata.copyWith(lastModified: 0, checkoutRef: _contentEqualityCheckoutSentinel),
  ),
);

/// One recorded edit and the committed state immediately after it.
@immutable
class FitHistoryEntry {
  const FitHistoryEntry({required this.action, required this.state});

  final FitEditAction action;

  /// Committed state, shared by reference and never copied.
  final FitStorage state;
}

/// Display state of one fit's in-session edit history.
@immutable
class FitHistoryState {
  const FitHistoryState({required this.entries, required this.cursor});

  factory FitHistoryState.empty() =>
      const FitHistoryState(entries: IList<FitHistoryEntry>.empty(), cursor: 0);

  /// Oldest (baseline) entry first, newest last.
  final IList<FitHistoryEntry> entries;

  /// Index of the entry whose state corresponds to the current committed state.
  final int cursor;

  bool get isSeeded => entries.isNotEmpty;
  int get length => entries.length;

  /// Consumers only observe the cursor, the entry count, and list identity;
  /// contained fit states are never compared here.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitHistoryState && other.cursor == cursor && identical(other.entries, entries);

  @override
  int get hashCode => Object.hash(cursor, entries.length);

  @override
  String toString() => "FitHistoryState(cursor: $cursor, length: ${entries.length})";
}

/// Owns no fit state; every navigation delegates to the fit editing contract.
///
/// The provider is kept alive for the session so history survives leaving and
/// reopening a fit, while still being scoped per fit id.
@Riverpod(keepAlive: true)
class FitHistory extends _$FitHistory {
  late String _fitId;

  @override
  FitHistoryState build(String fitId) {
    _fitId = fitId;
    return FitHistoryState.empty();
  }

  bool get _isEditable {
    final fitState = ref.read(fitProvider(_fitId));
    if (!fitState.isInitialized) return false;

    final checkoutId = ref.read(activeCheckoutIdProvider);
    final active = ref.read(activeCheckoutProvider);
    return checkFitCompatibility(
      fitState.fit.metadata,
      activeCheckoutId: checkoutId.match(() => "", (id) => id),
      activeServerId: active.match(() => "", (a) => a.serverId),
    ).allowsEditing;
  }

  bool get canUndo => state.isSeeded && state.cursor > 0 && _isEditable;
  bool get canRedo => state.isSeeded && state.cursor < state.length - 1 && _isEditable;

  /// Replaces the history with a single [FitEditAction.openedFit] baseline.
  void seed(FitStorage fit) {
    state = FitHistoryState(
      entries: IList([FitHistoryEntry(action: const FitEditAction.openedFit(), state: fit)]),
      cursor: 0,
    );
    debug("history: seeded fit=$_fitId cursor=0 entries=1");
  }

  /// Discards all previous entries and keeps only the current committed state.
  void clear() {
    final fitState = ref.read(fitProvider(_fitId));
    if (!fitState.isInitialized) {
      warning("history: clear rejected for fit=$_fitId: not initialized");
      return;
    }
    seed(fitState.fit);
    debug("history: cleared fit=$_fitId");
  }

  /// Appends a committed edit, truncating the redoable future.
  void record(FitEditAction action, FitStorage committed) {
    final current = state;
    if (!current.isSeeded) {
      warning("history: record without seed for fit=$_fitId action=${action.kind.name}");
      seed(committed);
      return;
    }

    if (fitContentEquals(committed, current.entries[current.cursor].state)) {
      debug(
        "history: suppressed content-equal action=${action.kind.name} "
        "fit=$_fitId cursor=${current.cursor} entries=${current.length}",
      );
      return;
    }

    final truncated = current.entries.sublist(0, current.cursor + 1).toList()
      ..add(FitHistoryEntry(action: action, state: committed));
    var entries = IList(truncated);
    var cursor = current.cursor + 1;
    var dropped = 0;

    if (entries.length > kFitHistoryCapacity) {
      dropped = entries.length - kFitHistoryCapacity;
      entries = entries.sublist(dropped).toIList();
      cursor = math.max(0, cursor - dropped);
      debug(
        "history: evicted $dropped entries fit=$_fitId action=${action.kind.name} "
        "cursor=$cursor entries=${entries.length}",
      );
    }

    state = FitHistoryState(entries: entries, cursor: cursor);
    debug(
      "history: recorded action=${action.kind.name} fit=$_fitId "
      "cursor=$cursor entries=${entries.length}",
    );
  }

  Future<void> undo() async {
    final current = state;
    if (!current.isSeeded || current.cursor <= 0) {
      warning("history: undo rejected for fit=$_fitId: at baseline");
      return;
    }
    if (!_isEditable) {
      warning("history: undo rejected for fit=$_fitId: not editable");
      return;
    }
    await _restoreAt(current.cursor - 1, "undo");
  }

  Future<void> redo() async {
    final current = state;
    if (!current.isSeeded || current.cursor >= current.length - 1) {
      warning("history: redo rejected for fit=$_fitId: at newest entry");
      return;
    }
    if (!_isEditable) {
      warning("history: redo rejected for fit=$_fitId: not editable");
      return;
    }
    await _restoreAt(current.cursor + 1, "redo");
  }

  Future<void> jumpTo(int index) async {
    final current = state;
    if (!current.isSeeded || index < 0 || index >= current.length) {
      warning("history: jump rejected for fit=$_fitId: invalid index $index");
      return;
    }
    if (!_isEditable) {
      warning("history: jump rejected for fit=$_fitId: not editable");
      return;
    }
    await _restoreAt(index, "jump");
  }

  Future<void> _restoreAt(int index, String reason) async {
    final previous = state;
    final entry = previous.entries[index];
    state = FitHistoryState(entries: previous.entries, cursor: index);

    final restored = await ref.read(fitProvider(_fitId).notifier).restore(entry.state);
    if (!restored) {
      state = previous;
      warning("history: restore rejected during $reason for fit=$_fitId cursor=$index");
      return;
    }
    debug(
      "history: $reason fit=$_fitId cursor=$index entries=${previous.length} "
      "action=${entry.action.kind.name}",
    );
  }
}
