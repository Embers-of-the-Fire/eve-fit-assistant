@TestOn("vm")
library;

import "dart:async";
import "dart:convert";
import "dart:io";

import "package:efa_proto/fit.pb.dart" as proto_fit;
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/fit/edit_action.dart";
import "package:eve_fit_assistant/storage/fit/history.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/storage/fs/doc_store.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:riverpod/riverpod.dart";

const String _fitId = "history-test-fit";

class _InMemoryDocStore implements DocStore {
  final Map<String, String> docs = {};
  Completer<void>? writeBlocker;

  @override
  Future<void> init() async {}

  @override
  Future<String?> read(String key) async => docs[key];

  @override
  Future<bool> exists(String key) async => docs.containsKey(key);

  @override
  Future<void> write(String key, String value) async {
    await writeBlocker?.future;
    docs[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    docs.remove(key);
  }

  @override
  Future<List<String>> keys() async => docs.keys.toList();
}

class _FakeFitRegistryManager extends FitRegistryManager {
  @override
  FitRegistry build() => FitRegistry(fits: const IMap.empty());

  @override
  void updateFit(FitMetadata metadata) {
    state = state.copyWith(fits: state.fits.add(metadata.fitId, metadata));
  }
}

proto_fit.Ship _ship() => proto_fit.Ship()
  ..typeId = 1234
  ..highSlots = 3
  ..mediumSlots = 3
  ..lowSlots = 3;

FitStorage _fit() => FitStorage.empty(
  const FitMetadata(
    fitId: _fitId,
    shipTypeId: 1234,
    name: "History Fit",
    lastModified: 0,
    description: "",
    // An empty checkout ref stays editable without an active checkout.
    checkoutRef: CheckoutRef(checkoutId: "", serverId: ""),
  ),
  _ship(),
);

void main() {
  setUpAll(() {
    GlobalLogger.init(
      Directory.systemTemp.createTempSync("efa-history-test").path,
      enableDebugLog: false,
    );
  });

  late _InMemoryDocStore store;
  late ProviderContainer container;
  late ProviderSubscription<FitServiceState> fitSubscription;

  Future<void> pump() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> load() async {
    final completer = Completer<void>();
    fitSubscription = container.listen<FitServiceState>(fitProvider(_fitId), (_, next) {
      if (next.isInitialized && !completer.isCompleted) completer.complete();
    }, fireImmediately: true);
    await completer.future;
    await pump();
  }

  setUp(() async {
    store = _InMemoryDocStore();
    store.docs["$_fitId.json"] = jsonEncode(encodeFitStorage(_fit()));
    container = ProviderContainer(
      overrides: [
        fitsDocStoreProvider.overrideWithValue(store),
        fitRegistryManagerProvider.overrideWith(_FakeFitRegistryManager.new),
        activeCheckoutProvider.overrideWithValue(const None()),
        activeCheckoutIdProvider.overrideWithValue(const None()),
      ],
    );
    await load();
  });

  tearDown(() {
    fitSubscription.close();
    container.dispose();
  });

  test("loads with an opened-fit baseline", () {
    final history = container.read(fitHistoryProvider(_fitId));
    expect(history.length, 1);
    expect(history.cursor, 0);
    expect(history.entries.single.action, const FitEditAction.openedFit());
  });

  test("records an edit and undoes/redoes it", () async {
    final fitNotifier = container.read(fitProvider(_fitId).notifier);
    final historyNotifier = container.read(fitHistoryProvider(_fitId).notifier);

    await fitNotifier.update(
      action: const FitEditAction.renameFit(),
      transform: (fit) => fit.copyWith(metadata: fit.metadata.copyWith(name: "Renamed")),
    );

    var history = container.read(fitHistoryProvider(_fitId));
    expect(history.length, 2);
    expect(history.cursor, 1);
    expect(history.entries.last.action, const FitEditAction.renameFit());
    expect(historyNotifier.canUndo, isTrue);
    expect(historyNotifier.canRedo, isFalse);

    await historyNotifier.undo();
    history = container.read(fitHistoryProvider(_fitId));
    expect(history.cursor, 0);
    expect(container.read(fitProvider(_fitId)).fit.metadata.name, "History Fit");
    expect(historyNotifier.canRedo, isTrue);

    await historyNotifier.redo();
    history = container.read(fitHistoryProvider(_fitId));
    expect(history.cursor, 1);
    expect(container.read(fitProvider(_fitId)).fit.metadata.name, "Renamed");
  });

  test("content-equal edits append no entry and keep the future", () async {
    final fitNotifier = container.read(fitProvider(_fitId).notifier);
    final historyNotifier = container.read(fitHistoryProvider(_fitId).notifier);

    await fitNotifier.update(
      action: const FitEditAction.renameFit(),
      transform: (fit) => fit.copyWith(metadata: fit.metadata.copyWith(name: "A")),
    );
    await historyNotifier.undo();

    await fitNotifier.update(
      action: const FitEditAction.editDescription(),
      transform: (fit) => fit.copyWith(metadata: fit.metadata.copyWith(description: "")),
    );

    final history = container.read(fitHistoryProvider(_fitId));
    expect(history.length, 2);
    expect(history.cursor, 0);
    expect(historyNotifier.canRedo, isTrue);
  });

  test("a new edit truncates the redoable future", () async {
    final fitNotifier = container.read(fitProvider(_fitId).notifier);
    final historyNotifier = container.read(fitHistoryProvider(_fitId).notifier);

    await fitNotifier.update(
      action: const FitEditAction.renameFit(),
      transform: (fit) => fit.copyWith(metadata: fit.metadata.copyWith(name: "A")),
    );
    await fitNotifier.update(
      action: const FitEditAction.editDescription(),
      transform: (fit) => fit.copyWith(metadata: fit.metadata.copyWith(description: "one")),
    );
    await historyNotifier.undo();
    await fitNotifier.update(
      action: const FitEditAction.editDescription(),
      transform: (fit) => fit.copyWith(metadata: fit.metadata.copyWith(description: "two")),
    );

    final history = container.read(fitHistoryProvider(_fitId));
    expect(history.length, 3);
    expect(history.cursor, 2);
    expect(history.entries.last.action, const FitEditAction.editDescription());
    expect(historyNotifier.canRedo, isFalse);
  });

  test("jump restores an arbitrary entry without recording", () async {
    final fitNotifier = container.read(fitProvider(_fitId).notifier);
    final historyNotifier = container.read(fitHistoryProvider(_fitId).notifier);

    for (final name in ["A", "B", "C"]) {
      await fitNotifier.update(
        action: const FitEditAction.renameFit(),
        transform: (fit) => fit.copyWith(metadata: fit.metadata.copyWith(name: name)),
      );
    }

    await historyNotifier.jumpTo(1);
    final history = container.read(fitHistoryProvider(_fitId));
    expect(history.cursor, 1);
    expect(history.length, 4);
    expect(container.read(fitProvider(_fitId)).fit.metadata.name, "A");
  });

  test("capacity eviction keeps the newest entries and cursor consistent", () async {
    final fitNotifier = container.read(fitProvider(_fitId).notifier);

    for (var i = 0; i < kFitHistoryCapacity + 5; i++) {
      await fitNotifier.update(
        action: const FitEditAction.renameFit(),
        transform: (fit) => fit.copyWith(metadata: fit.metadata.copyWith(name: "name-$i")),
      );
    }

    final history = container.read(fitHistoryProvider(_fitId));
    expect(history.length, kFitHistoryCapacity);
    expect(history.cursor, kFitHistoryCapacity - 1);
    expect(history.entries.last.action, const FitEditAction.renameFit());
    expect(container.read(fitProvider(_fitId)).fit.metadata.name, "name-54");
  });

  test("reload re-seeds the history to one baseline", () async {
    final fitNotifier = container.read(fitProvider(_fitId).notifier);
    await fitNotifier.update(
      action: const FitEditAction.renameFit(),
      transform: (fit) => fit.copyWith(metadata: fit.metadata.copyWith(name: "A")),
    );
    expect(container.read(fitHistoryProvider(_fitId)).length, 2);

    await fitNotifier.reload();
    await pump();

    final history = container.read(fitHistoryProvider(_fitId));
    expect(history.length, 1);
    expect(history.cursor, 0);
  });

  test("reload waits for pending writes before reseeding history", () async {
    final fitNotifier = container.read(fitProvider(_fitId).notifier);
    final historyNotifier = container.read(fitHistoryProvider(_fitId).notifier);
    final writeBlocker = Completer<void>();
    store.writeBlocker = writeBlocker;

    final edit = fitNotifier.update(
      action: const FitEditAction.renameFit(),
      transform: (fit) => fit.copyWith(metadata: fit.metadata.copyWith(name: "Before reload")),
    );
    await pump();
    final reload = fitNotifier.reload();
    await pump();

    writeBlocker.complete();
    await Future.wait([edit, reload]);

    var history = container.read(fitHistoryProvider(_fitId));
    expect(history.length, 1);
    expect(history.entries.single.state.metadata.name, "Before reload");

    await fitNotifier.update(
      action: const FitEditAction.renameFit(),
      transform: (fit) => fit.copyWith(metadata: fit.metadata.copyWith(name: "After reload")),
    );
    await historyNotifier.undo();

    history = container.read(fitHistoryProvider(_fitId));
    expect(history.cursor, 0);
    expect(container.read(fitProvider(_fitId)).fit.metadata.name, "Before reload");
  });

  test("history survives fit provider disposal and remount", () async {
    final fitNotifier = container.read(fitProvider(_fitId).notifier);
    await fitNotifier.update(
      action: const FitEditAction.renameFit(),
      transform: (fit) => fit.copyWith(metadata: fit.metadata.copyWith(name: "Kept")),
    );
    expect(container.read(fitHistoryProvider(_fitId)).length, 2);

    fitSubscription.close();
    await pump();
    expect(container.read(fitHistoryProvider(_fitId)).length, 2);

    await load();
    final history = container.read(fitHistoryProvider(_fitId));
    expect(history.length, 2);
    expect(history.cursor, 1);
  });

  test("content equality ignores restamped metadata and prunes orphans", () {
    final base = _fit();
    final restamped = base.copyWith(
      metadata: base.metadata.copyWith(
        lastModified: 123456,
        checkoutRef: const CheckoutRef(checkoutId: "different", serverId: "other"),
      ),
    );
    expect(fitContentEquals(base, restamped), isTrue);

    final named = restamped.copyWith(metadata: restamped.metadata.copyWith(name: "Other"));
    expect(fitContentEquals(base, named), isFalse);
  });
}
