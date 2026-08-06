import "dart:js_interop";

import "package:web/web.dart" as web;

/// Web variant: fetches [jsUrl] and verifies it is actually JavaScript.
///
/// A `HEAD` request is used so the probe does not download the multi-MB
/// bundle on every startup. Dev servers and SPA hosts answer missing paths
/// with a `200 text/html` fallback page, so the status code alone is not
/// enough; the content type must be checked as well.
Future<bool> wasmBundleAvailable(String jsUrl) async {
  try {
    final response = await web.window.fetch(jsUrl.toJS, web.RequestInit(method: "HEAD")).toDart;
    if (!response.ok) return false;
    final contentType = response.headers.get("content-type") ?? "";
    return contentType.contains("javascript") || contentType.contains("ecmascript");
  } on Object {
    return false;
  }
}

/// Whether the page is cross-origin isolated (COOP + COEP headers present).
///
/// The engine wasm is built with atomics so FRB can run engine calls in a Web
/// Worker pool; the shared memory this requires (`SharedArrayBuffer`) is only
/// exposed on isolated origins.
bool crossOriginIsolated() {
  try {
    return web.window.crossOriginIsolated;
  } on Object {
    return false;
  }
}
