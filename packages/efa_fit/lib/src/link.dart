import "package:efa_fit/src/efa_format.dart";

const String efaScheme = "efa";
const String fitLinkShareHost = "share.platform.efa-tech.dev";
const String fitLinkProdHost = "app.efa-tech.dev";
const String fitLinkNightlyHost = "app-preview.efa-tech.dev";
const String fitLinkCanonicalPath = "/fit/raw";
const String fitLinkPayloadParam = "payload";
const int maxFitLinkUrlLength = 8000;

const List<String> fitLinkHttpsHosts = [fitLinkShareHost, fitLinkProdHost, fitLinkNightlyHost];

class FitLinkNotFoundException implements Exception {
  const FitLinkNotFoundException(this.uri);

  final Uri uri;

  @override
  String toString() => "FitLinkNotFoundException($uri)";
}

class FitLinkParseResult {
  const FitLinkParseResult({required this.payload, required this.queryParameters});

  final String payload;
  final Map<String, String> queryParameters;
}

String buildFitLinkShareUrl(String payload) {
  assert(payload.startsWith(efaFitLinkPayloadPrefix));
  final url = "https://$fitLinkShareHost$fitLinkCanonicalPath?$fitLinkPayloadParam=$payload";
  assert(url.length <= maxFitLinkUrlLength);
  return url;
}

String? canonicalPathOf(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  if (scheme == efaScheme) {
    final combined = uri.hasAuthority ? "${uri.host}${uri.path}" : uri.path;
    final normalized = combined.startsWith("/") ? combined : "/$combined";
    return normalized.toLowerCase() == fitLinkCanonicalPath ? fitLinkCanonicalPath : null;
  }
  if (scheme == "https") {
    if (!fitLinkHttpsHosts.contains(uri.host.toLowerCase())) return null;
    return uri.path == fitLinkCanonicalPath ? fitLinkCanonicalPath : null;
  }
  return null;
}

FitLinkParseResult? parseFitLinkUri(Uri uri) {
  if (canonicalPathOf(uri) == null) return null;
  return _readQuery(uri);
}

FitLinkParseResult? parseFitLinkBootUri(Uri uri) {
  if (uri.path != fitLinkCanonicalPath) return null;
  return _readQuery(uri);
}

FitLinkParseResult? _readQuery(Uri uri) {
  final Map<String, String> queryParameters;
  try {
    queryParameters = uri.queryParameters;
  } on FormatException {
    return null;
  }
  final payload = queryParameters[fitLinkPayloadParam];
  if (payload == null) return null;
  return FitLinkParseResult(payload: payload, queryParameters: queryParameters);
}
