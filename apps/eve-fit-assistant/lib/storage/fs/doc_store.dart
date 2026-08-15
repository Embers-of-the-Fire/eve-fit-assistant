/// User-data domains persisted through a [DocStore].
///
/// Each domain maps to a directory on native and a Hive box (IndexedDB) on
/// web. The [boxName] is the web-side Hive box identifier.
enum UserDataDomain {
  fittings("efa_fittings"),
  characters("efa_characters"),
  settings("efa_settings"),
  chat("efa_chat");

  const UserDataDomain(this.boxName);

  final String boxName;
}

/// Platform-agnostic key/value document store for user data (fits, characters,
/// settings, small state files).
///
/// Values are opaque strings (typically JSON). Implementations:
/// - `FileDocStore` (native): one file per key under a domain directory.
/// - `HiveDocStore` (web): Hive CE box backed by IndexedDB.
///
/// All operations are async because the web backend (IndexedDB) is async-only.
abstract interface class DocStore {
  /// Performs platform-specific initialization (creates the domain directory on
  /// native, opens the Hive box on web). Idempotent; methods also await it.
  Future<void> init();

  /// Reads the document at [key], or `null` when absent.
  Future<String?> read(String key);

  /// Returns whether a document exists at [key].
  Future<bool> exists(String key);

  /// Writes [value] to [key], creating parents as needed. Atomic per document.
  Future<void> write(String key, String value);

  /// Deletes the document at [key]. No-op when absent.
  Future<void> delete(String key);

  /// Lists all keys in the domain.
  Future<List<String>> keys();
}
