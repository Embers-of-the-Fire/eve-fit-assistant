import "dart:typed_data";

/// Platform-agnostic byte storage for the repo tree (`resources/v2/`).
///
/// Paths are opaque strings produced by `RepoPaths`: absolute filesystem paths
/// on native platforms, absolute-shaped keys on web (the OPFS backend strips
/// the well-known `resources/v2` prefix internally). All operations are
/// asynchronous because the web backend (OPFS) is async-only.
///
/// Implementations:
/// - `FileBlobStore` (native): `dart:io` files with tmp-then-rename atomic
///   writes.
/// - `OpfsBlobStore` (web): Origin Private File System; writes are atomic on
///   stream close per the File System Access spec.
/// - `MemoryBlobStore`: in-memory, for tests.
abstract interface class BlobStore {
  /// Performs platform-specific initialization (e.g. acquiring the OPFS root
  /// directory). Must complete before any other operation; implementations
  /// make every method wait for it, so calling it explicitly is only a
  /// startup-latency optimization.
  Future<void> init();

  /// Reads the file at [path]. Returns `null` when the file does not exist or
  /// cannot be read.
  Future<Uint8List?> read(String path);

  /// Returns whether a file exists at [path].
  Future<bool> exists(String path);

  /// Writes [bytes] to [path], creating parent directories as needed.
  ///
  /// The write is atomic per file: readers never observe a partially written
  /// file (tmp-then-rename on native, swap-file commit on OPFS).
  Future<void> write(String path, Uint8List bytes);

  /// Deletes the file at [path]. No-op when the file does not exist.
  Future<void> delete(String path);

  /// Lists all files under [prefix] recursively.
  ///
  /// Returned paths use the same form as [prefix] (i.e. comparable against
  /// `RepoPaths` outputs). Returns an empty list when [prefix] does not exist.
  Future<List<String>> list(String prefix);

  /// Deletes the file or directory tree at [path] recursively. No-op when the
  /// path does not exist.
  Future<void> deleteTree(String path);
}
