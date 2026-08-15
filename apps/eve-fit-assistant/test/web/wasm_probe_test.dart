@TestOn("browser")
library;

import "package:eve_fit_assistant/compat/wasm_probe.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("wasmBundleAvailable accepts a real JavaScript bundle", () async {
    // Staged by `x.py test web` from web/sqlite/.
    expect(await wasmBundleAvailable("/web/sqlite/db_worker.js"), isTrue);
  });

  test("wasmBundleAvailable rejects missing paths and SPA fallbacks", () async {
    // The test server answers unknown paths with a 404 (dev/SPA hosts with a
    // `200 text/html` fallback); either way the probe must not treat the
    // response as a bundle.
    expect(await wasmBundleAvailable("/web/sqlite/definitely_missing.js"), isFalse);
  });

  test("crossOriginIsolated is false in the headless test harness", () {
    // Pins the assumption the other web suites rely on: without COOP/COEP the
    // native engine and the localization database stay unavailable.
    expect(crossOriginIsolated(), isFalse);
  });
}
