/// Platform compatibility layer for `dart:isolate`.
///
/// On native platforms this re-exports `dart:isolate` directly. On web it
/// exports stubs that run work inline on the main event loop (web has no
/// isolates), keeping call sites source-compatible.
library;

export "dart:isolate" if (dart.library.js_interop) "isolate_stub.dart";
