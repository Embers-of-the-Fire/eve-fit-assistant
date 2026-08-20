import "package:efa_fit/efa_fit.dart";
import "package:web/web.dart" as web;

Uri? _pending;

void probeFitLinkBootUrl() {
  final uri = Uri.base;
  if (uri.path != fitLinkCanonicalPath && uri.path != fitLinkRegisteredCanonicalPath) return;
  final Map<String, String> queryParameters;
  try {
    queryParameters = uri.queryParameters;
  } on FormatException {
    return;
  }
  final recognized = switch (uri.path) {
    fitLinkRegisteredCanonicalPath => fitLinkHashPattern.hasMatch(
      queryParameters[fitLinkHashParam] ?? "",
    ),
    _ => queryParameters[fitLinkPayloadParam]?.startsWith(efaFitLinkPayloadPrefix) ?? false,
  };
  if (!recognized) return;
  _pending = uri;
  web.window.history.replaceState(null, "", "/");
}

Uri? takeBootFitLink() {
  final uri = _pending;
  _pending = null;
  return uri;
}
