import "dart:convert";

import "package:dio/dio.dart";
import "package:efa_fit/efa_fit.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/killmail_import/killboard_server.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";

enum KillboardFetchErrorCode { notFound, blocked, fetchFailed, invalidResponse }

class KillboardFetchException implements Exception {
  const KillboardFetchException(this.code, {this.detail});

  final KillboardFetchErrorCode code;
  final String? detail;

  @override
  String toString() => "KillboardFetchException($code, detail: $detail)";
}

/// HTTP client for killboard killmail lookups.
///
/// Owns its Dio instance internally; callers never see HTTP details.
class KillboardClient {
  KillboardClient({Dio? dio}) : _dio = dio ?? createRemoteDio(useCache: false);

  final Dio _dio;

  static final RegExp _urlPattern = RegExp(
    r"^(?:https?://)?(?<host>[^/\s]+)/kill/(?<id>\d+)/?$",
    caseSensitive: false,
  );

  /// Parses a killboard kill URL (`zkillboard.com/kill/<id>/`, with or
  /// without scheme) into its server and killmail ID. Returns `null` for
  /// anything else, including bare IDs.
  static (KillboardServer, int)? parseKillUrl(String input) {
    final match = _urlPattern.firstMatch(input.trim());
    if (match == null) return null;
    final server = KillboardServer.forHost(match.namedGroup("host")!);
    if (server == null) return null;
    return (server, int.parse(match.namedGroup("id")!));
  }

  Uri killmailUriFor(KillboardServer server, int killmailId) => server.killmailApiUri(killmailId);

  /// Fetches and parses the killmail [killmailId] from [server].
  ///
  /// A server protected by a bot mitigation layer may answer with an HTML
  /// challenge page; those responses surface as
  /// [KillboardFetchErrorCode.blocked] so callers can offer a JSON-paste
  /// fallback. Killboards withhold very recent killmails (zKillboard: five
  /// minutes) and answer unknown IDs with an empty JSON array; both surface
  /// as [KillboardFetchErrorCode.notFound].
  Future<Killmail> fetchKillmail(KillboardServer server, int killmailId) async {
    final uri = killmailUriFor(server, killmailId);
    final Response<String> response;
    try {
      response = await _dio.getUri<String>(uri, options: Options(responseType: ResponseType.plain));
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      warning("Killmail fetch failed for $uri (HTTP $status): $error");
      if (status == 404) {
        throw KillboardFetchException(KillboardFetchErrorCode.notFound, detail: "$killmailId");
      }
      if (status == 401 || status == 403) {
        throw const KillboardFetchException(KillboardFetchErrorCode.blocked);
      }
      throw const KillboardFetchException(KillboardFetchErrorCode.fetchFailed);
    }

    final data = response.data;
    if (data == null) {
      warning("Killmail fetch for $uri returned an empty body");
      throw const KillboardFetchException(KillboardFetchErrorCode.fetchFailed);
    }
    final trimmed = data.trim();
    if (!trimmed.startsWith("[") && !trimmed.startsWith("{")) {
      warning(
        "Killmail fetch for $uri returned a non-JSON body (WAF challenge?): ${_preview(data)}",
      );
      throw const KillboardFetchException(KillboardFetchErrorCode.blocked);
    }
    if (trimmed == "[]") {
      throw KillboardFetchException(KillboardFetchErrorCode.notFound, detail: "$killmailId");
    }
    final Object? decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic> && decoded["error"] != null) {
      warning("Killmail fetch for $uri returned an error object: ${decoded["error"]}");
      throw KillboardFetchException(
        KillboardFetchErrorCode.fetchFailed,
        detail: "${decoded["error"]}",
      );
    }
    try {
      return parseKillmailJson(trimmed);
    } on KillmailFormatException {
      warning("Killmail fetch for $uri returned unparseable JSON: ${_preview(trimmed)}");
      throw const KillboardFetchException(KillboardFetchErrorCode.invalidResponse);
    }
  }

  static String _preview(String body) => body.length <= 200 ? body : "${body.substring(0, 200)}...";

  void dispose() => _dio.close();
}
