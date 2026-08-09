import "dart:js_interop";

import "package:web/web.dart" as web;

/// Web variant: fetches [jsUrl] and verifies it is actually JavaScript.
///
/// A `HEAD` request is used so the probe does not download the multi-MB
/// bundle on every startup. Flutter's dev web server serves assets via `GET`
/// only and 404s `HEAD` (flutter_tools `web_asset_server.dart`), so a failed
/// or non-OK `HEAD` falls back to a `GET` that is aborted as soon as the
/// headers arrive — the dev server ignores `Range` and would otherwise
/// stream the whole bundle just for the probe.
///
/// Dev servers and SPA hosts answer missing paths with a `200 text/html`
/// fallback page, so the status code alone is not enough; the content type
/// must be checked as well.
Future<bool> wasmBundleAvailable(String jsUrl) async {
  try {
    final head = await web.window.fetch(jsUrl.toJS, web.RequestInit(method: "HEAD")).toDart;
    if (head.ok) return _isJavaScript(head.headers);

    final abort = web.AbortController();
    final get = await web.window
        .fetch(jsUrl.toJS, web.RequestInit(method: "GET", signal: abort.signal))
        .toDart;
    abort.abort();
    return get.ok && _isJavaScript(get.headers);
  } on Object {
    return false;
  }
}

bool _isJavaScript(web.Headers headers) {
  final contentType = headers.get("content-type") ?? "";
  return contentType.contains("javascript") || contentType.contains("ecmascript");
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
