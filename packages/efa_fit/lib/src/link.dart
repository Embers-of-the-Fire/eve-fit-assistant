import "package:efa_fit/src/efa_format.dart";

const String efaScheme = "efa";
const String fitLinkPlatformHost = "platform.efa-tech.dev";
const String fitLinkLegacyShareHost = "share.platform.efa-tech.dev";
const String fitLinkProdHost = "app.efa-tech.dev";
const String fitLinkNightlyHost = "app-preview.efa-tech.dev";
const String fitLinkCanonicalPath = "/fit/raw";
const String fitLinkPlatformPath = "/share/fit/raw";
const String fitLinkPayloadParam = "payload";
const int maxFitLinkUrlLength = 8000;

const List<String> fitLinkLegacyHttpsHosts = [
  fitLinkLegacyShareHost,
  fitLinkProdHost,
  fitLinkNightlyHost,
];
const List<String> fitLinkHttpsHosts = [fitLinkPlatformHost, ...fitLinkLegacyHttpsHosts];

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
  validateEfaFitLinkPayload(payload);
  final url = "https://$fitLinkPlatformHost$fitLinkPlatformPath?$fitLinkPayloadParam=$payload";
  if (url.length > maxFitLinkUrlLength) {
    throw const EfaFitFormatException(EfaFitFormatErrorCode.payloadTooLarge);
  }
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
    final host = uri.host.toLowerCase();
    if (host == fitLinkPlatformHost) {
      return uri.path == fitLinkPlatformPath ? fitLinkPlatformPath : null;
    }
    if (fitLinkLegacyHttpsHosts.contains(host)) {
      return uri.path == fitLinkCanonicalPath ? fitLinkCanonicalPath : null;
    }
    return null;
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
