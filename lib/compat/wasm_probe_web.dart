import "dart:js_interop";

import "package:web/web.dart" as web;

/// Web variant: fetches [jsUrl] and verifies it is actually JavaScript.
///
/// Dev servers and SPA hosts answer missing paths with a `200 text/html`
/// fallback page, so the status code alone is not enough; the content type
/// must be checked as well.
Future<bool> wasmBundleAvailable(String jsUrl) async {
  try {
    final response = await web.window.fetch(jsUrl.toJS).toDart;
    if (!response.ok) return false;
    final contentType = response.headers.get("content-type") ?? "";
    return contentType.contains("javascript") || contentType.contains("ecmascript");
  } on Object {
    return false;
  }
}
