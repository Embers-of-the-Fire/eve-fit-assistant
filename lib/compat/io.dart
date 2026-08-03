/// Platform compatibility layer for `dart:io`.
///
/// On native platforms this re-exports `dart:io` directly. On web (where
/// `dart:io` is unavailable) it exports stub declarations that compile but
/// throw [UnsupportedError] when any filesystem or process API is used.
library;

export "dart:io" if (dart.library.js_interop) "io_stub.dart";
