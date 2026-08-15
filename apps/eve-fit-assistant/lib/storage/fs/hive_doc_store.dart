import "package:eve_fit_assistant/storage/fs/doc_store.dart";
import "package:hive_ce/hive_ce.dart";

/// Web [DocStore] backed by a Hive CE box (persisted to IndexedDB).
///
/// This file is only reachable through the `user_store_web.dart` conditional
/// export — it must stay out of the native compile graph to keep Hive's web
/// backend assumptions intact.
class HiveDocStore implements DocStore {
  HiveDocStore(this._boxName);

  final String _boxName;

  Box<String>? _box;
  Future<void>? _ready;

  @override
  Future<void> init() => _ready ??= _doInit();

  Future<void> _doInit() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  Future<Box<String>> get _boxReady async {
    await init();
    final box = _box;
    if (box == null) throw StateError("Hive box unavailable: $_boxName");
    return box;
  }

  @override
  Future<String?> read(String key) async => (await _boxReady).get(key);

  @override
  Future<bool> exists(String key) async => (await _boxReady).containsKey(key);

  @override
  Future<void> write(String key, String value) async => (await _boxReady).put(key, value);

  @override
  Future<void> delete(String key) async => (await _boxReady).delete(key);

  @override
  Future<List<String>> keys() async => (await _boxReady).keys.cast<String>().toList();

  /// Closes the underlying Hive box and resets the store so a later [init]
  /// reopens it. Closing flushes pending writes; delete-from-disk without a
  /// close can race those flushes on IndexedDB.
  Future<void> close() async {
    final box = _box;
    _box = null;
    _ready = null;
    await box?.close();
  }
}
