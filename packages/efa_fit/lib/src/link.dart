import "package:efa_fit/src/efa_format.dart";

const String efaScheme = "efa";
const String fitLinkPlatformHost = "platform.efa-tech.dev";
const String fitLinkLegacyShareHost = "share.platform.efa-tech.dev";
const String fitLinkProdHost = "app.efa-tech.dev";
const String fitLinkNightlyHost = "app-preview.efa-tech.dev";
const String fitLinkCanonicalPath = "/fit/raw";
const String fitLinkPlatformPath = "/share/fit/raw";
const String fitLinkPayloadParam = "payload";
const String fitLinkRegisteredCanonicalPath = "/fit/registered";
const String fitLinkRegisteredPlatformPath = "/share/fit/registered";
const String fitLinkHashParam = "hash";
const int maxFitLinkUrlLength = 8000;

/// A registered fit hash is the lowercase hex sha256 of the canonical fit
/// state (`worker/efa-platform-fit-storage/src/hash.rs`).
final RegExp fitLinkHashPattern = RegExp(r"^[0-9a-f]{64}$");

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

sealed class FitLinkParseResult {
  const FitLinkParseResult({required this.queryParameters});

  final Map<String, String> queryParameters;
}

/// A raw fit link: the fit travels inside the URL itself (`?payload=EFA2:...`).
class FitLinkRaw extends FitLinkParseResult {
  const FitLinkRaw({required this.payload, required super.queryParameters});

  final String payload;
}

/// A registered fit link: the URL carries only the content-addressed fit hash
/// (`?hash=...`); the fit is retrieved from the platform API by the consumer.
class FitLinkRegistered extends FitLinkParseResult {
  const FitLinkRegistered({required this.fitHash, required super.queryParameters});

  final String fitHash;
}

String buildFitLinkShareUrl(String payload) {
  validateEfaFitLinkPayload(payload);
  final url = "https://$fitLinkPlatformHost$fitLinkPlatformPath?$fitLinkPayloadParam=$payload";
  if (url.length > maxFitLinkUrlLength) {
    throw const EfaFitFormatException(EfaFitFormatErrorCode.payloadTooLarge);
  }
  return url;
}

String buildFitLinkRegisteredShareUrl(String fitHash) {
  if (!fitLinkHashPattern.hasMatch(fitHash)) {
    throw const EfaFitFormatException(EfaFitFormatErrorCode.invalidHash);
  }
  return "https://$fitLinkPlatformHost$fitLinkRegisteredPlatformPath?$fitLinkHashParam=$fitHash";
}

/// The `efa://` registered fit link for [fitHash]: the in-app counterpart of
/// [buildFitLinkRegisteredShareUrl], used when the consumer is already the
/// app (e.g. the platform post page's open-in-app action).
Uri buildFitLinkRegisteredAppUri(String fitHash) => Uri(
  scheme: efaScheme,
  host: "fit",
  path: "registered",
  queryParameters: {fitLinkHashParam: fitHash},
);

/// The canonical fit path of [uri] (`/fit/raw` or `/fit/registered`),
/// null when [uri] is not a recognized fit link.
String? canonicalPathOf(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  if (scheme == efaScheme) {
    final combined = uri.hasAuthority ? "${uri.host}${uri.path}" : uri.path;
    final normalized = combined.startsWith("/") ? combined : "/$combined";
    return switch (normalized.toLowerCase()) {
      fitLinkCanonicalPath => fitLinkCanonicalPath,
      fitLinkRegisteredCanonicalPath => fitLinkRegisteredCanonicalPath,
      _ => null,
    };
  }
  if (scheme == "https") {
    final host = uri.host.toLowerCase();
    if (host == fitLinkPlatformHost) {
      return switch (uri.path) {
        fitLinkPlatformPath => fitLinkCanonicalPath,
        fitLinkRegisteredPlatformPath => fitLinkRegisteredCanonicalPath,
        _ => null,
      };
    }
    if (fitLinkLegacyHttpsHosts.contains(host)) {
      return switch (uri.path) {
        fitLinkCanonicalPath => fitLinkCanonicalPath,
        fitLinkRegisteredCanonicalPath => fitLinkRegisteredCanonicalPath,
        _ => null,
      };
    }
    return null;
  }
  return null;
}

FitLinkParseResult? parseFitLinkUri(Uri uri) {
  final canonicalPath = canonicalPathOf(uri);
  if (canonicalPath == null) return null;
  return _readQuery(uri, canonicalPath);
}

FitLinkParseResult? parseFitLinkBootUri(Uri uri) {
  final canonicalPath = switch (uri.path) {
    fitLinkCanonicalPath => fitLinkCanonicalPath,
    fitLinkRegisteredCanonicalPath => fitLinkRegisteredCanonicalPath,
    _ => null,
  };
  if (canonicalPath == null) return null;
  return _readQuery(uri, canonicalPath);
}

FitLinkParseResult? _readQuery(Uri uri, String canonicalPath) {
  final Map<String, String> queryParameters;
  try {
    queryParameters = uri.queryParameters;
  } on FormatException {
    return null;
  }
  if (canonicalPath == fitLinkRegisteredCanonicalPath) {
    final fitHash = queryParameters[fitLinkHashParam];
    if (fitHash == null || !fitLinkHashPattern.hasMatch(fitHash)) return null;
    return FitLinkRegistered(fitHash: fitHash, queryParameters: queryParameters);
  }
  final payload = queryParameters[fitLinkPayloadParam];
  if (payload == null) return null;
  return FitLinkRaw(payload: payload, queryParameters: queryParameters);
}
