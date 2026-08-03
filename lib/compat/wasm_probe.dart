/// Probes whether a JavaScript/WASM bundle is actually servable before
/// letting flutter_rust_bridge inject a `<script>` tag for it.
///
/// FRB's web loader awaits the script's `onLoad`, which never fires when the
/// bundle is missing (the browser reports `onError` instead), so calling
/// `RustLib.init()` without this probe would hang app startup forever.
library;

export "wasm_probe_io.dart" if (dart.library.js_interop) "wasm_probe_web.dart";
