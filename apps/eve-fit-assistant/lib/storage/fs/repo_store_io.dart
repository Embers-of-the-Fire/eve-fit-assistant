import "package:eve_fit_assistant/storage/fs/blob_store.dart";
import "package:eve_fit_assistant/storage/fs/file_blob_store.dart";

/// Creates a repo blob store for native platforms.
///
/// The store is stateless (paths are absolute), so each call returns a fresh
/// instance and isolate entry points can safely construct their own.
BlobStore createRepoBlobStore() => FileBlobStore();
