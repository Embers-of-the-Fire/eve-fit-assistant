import "dart:convert";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/remote_content/endpoint.dart";
import "package:eve_fit_assistant/features/remote_content/etag_cache.dart";

/// Result from a conditional HTTP fetch.
///
/// When [notModified] is true, the server returned HTTP 304 and the caller
/// should use its locally cached data.
final class ConditionalFetchResult<T> {
  const ConditionalFetchResult({required this.response, required this.notModified});

  factory ConditionalFetchResult.modified(Response<T> response) =>
      ConditionalFetchResult<T>(response: response, notModified: false);

  factory ConditionalFetchResult.notModified() => ConditionalFetchResult<T>(
    response: Response<T>(requestOptions: RequestOptions()),
    notModified: true,
  );

  final Response<T> response;
  final bool notModified;
}

Future<Map<String, dynamic>> fetchRemoteJson(
  Dio dio,
  Uri uri, {
  Map<String, dynamic>? cachedPayload,
}) async {
  ConditionalFetchResult<String> result = await getRemoteUri<String>(dio, uri);
  if (result.notModified) {
    if (cachedPayload != null) {
      return cachedPayload;
    }
    warning(
      "Remote JSON returned 304 but no cached payload available for $uri."
      " The ETag may be stale; clearing and retrying.",
    );
    EtagCache.remove(uri);
    result = await getRemoteUri<String>(dio, uri);
    if (result.notModified) {
      throw RemoteContentException(
        "Remote JSON not modified but no cached payload available: $uri",
      );
    }
  }
  final data = result.response.data;
  if (data is! String) {
    throw RemoteContentException("Remote JSON response is not text: $uri");
  }
  final decoded = jsonDecode(data);
  if (decoded is! Map<String, dynamic>) {
    throw RemoteContentException("Remote JSON response is not an object: $uri");
  }
  return decoded;
}

/// Fetches a remote URI with conditional request headers.
///
/// If a cached ETag or Last-Modified exists for [uri], they are sent as
/// `If-None-Match` and `If-Modified-Since` respectively.  When the server
/// responds with HTTP 304, [ConditionalFetchResult.notModified] is true.
/// Otherwise the response headers are used to update the [EtagCache].
Future<ConditionalFetchResult<T>> getRemoteUri<T>(
  Dio dio,
  Uri uri, {
  ResponseType responseType = ResponseType.plain,
}) async {
  final cachedEtag = EtagCache.getEtag(uri);
  final cachedLastModified = EtagCache.getLastModified(uri);

  try {
    final response = await dio.getUri<T>(
      uri,
      options: Options(
        responseType: responseType,
        headers: _conditionalHeaders(cachedEtag, cachedLastModified),
      ),
    );
    _updateCacheFromResponse(uri, response);
    return ConditionalFetchResult<T>.modified(response);
  } on DioException catch (exception) {
    if (exception.response?.statusCode == 304) {
      return ConditionalFetchResult<T>.notModified();
    }
    final response = exception.response;
    final status = response?.statusCode;
    final body = response?.data?.toString();
    final bodySnippet = body == null || body.length <= 300 ? body : body.substring(0, 300);
    throw RemoteContentException(
      "Remote request failed for $uri"
      "${status == null ? "" : " with HTTP $status"}"
      "${bodySnippet == null || bodySnippet.isEmpty ? "" : ": $bodySnippet"}",
    );
  }
}

Map<String, dynamic>? _conditionalHeaders(String? etag, String? lastModified) {
  if (etag == null && lastModified == null) {
    return null;
  }
  return {"If-None-Match": ?etag, "If-Modified-Since": ?lastModified};
}

void _updateCacheFromResponse(Uri uri, Response<dynamic> response) {
  final headers = response.headers.map;
  if (headers.isEmpty) {
    return;
  }
  final etag = _extractSingleHeader(headers, "etag");
  final lastModified = _extractSingleHeader(headers, "last-modified");
  if (etag != null || lastModified != null) {
    EtagCache.update(uri, etag: etag, lastModified: lastModified);
  }
}

String? _extractSingleHeader(Map<String, List<String>> headers, String name) {
  final values = headers[name];
  if (values == null || values.isEmpty) {
    return null;
  }
  return values.first;
}
