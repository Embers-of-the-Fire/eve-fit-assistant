/// Platform factory for the repo `BlobStore`.
///
/// On native platforms this exports `repo_store_io.dart` (a fresh
/// `FileBlobStore` per call — the store is stateless, so isolates can create
/// their own). On web it exports `repo_store_web.dart` (the shared
/// `OpfsBlobStore` singleton, since web "isolates" run inline).
library;

export "repo_store_io.dart" if (dart.library.js_interop) "repo_store_web.dart";
