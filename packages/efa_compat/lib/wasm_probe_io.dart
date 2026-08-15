/// IO variant: WASM bundles are a web concern; always report available.
Future<bool> wasmBundleAvailable(String jsUrl) async => true;

/// IO variant: cross-origin isolation is a web concern; native threads work
/// everywhere, so always report isolated.
bool crossOriginIsolated() => true;
