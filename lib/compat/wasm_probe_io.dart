/// IO variant: WASM bundles are a web concern; always report available.
Future<bool> wasmBundleAvailable(String jsUrl) async => true;
