import "package:eve_fit_assistant/storage/fs/blob_store.dart";
import "package:eve_fit_assistant/storage/fs/opfs_blob_store.dart";

/// Returns the shared OPFS-backed repo blob store.
///
/// Web has no real isolates — `Isolate.run` executes inline — so every
/// consumer must share one instance to observe consistent OPFS state.
BlobStore createRepoBlobStore() => OpfsBlobStore.instance;
