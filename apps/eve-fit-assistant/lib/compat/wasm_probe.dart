/// Probes web preconditions of the native engine before letting
/// flutter_rust_bridge initialize it.
///
/// FRB's web loader awaits the script's `onLoad`, which never fires when the
/// bundle is missing (the browser reports `onError` instead), so calling
/// `RustLib.init()` without the bundle probe would hang app startup forever.
///
/// The engine wasm is additionally built with atomics so FRB can offload
/// engine calls to its Web Worker pool; that requires a cross-origin isolated
/// origin, which the isolation probe checks up front.
library;

export "wasm_probe_io.dart" if (dart.library.js_interop) "wasm_probe_web.dart";
