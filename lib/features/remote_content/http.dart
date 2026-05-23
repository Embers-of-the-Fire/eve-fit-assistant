import "dart:convert";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/features/remote_content/endpoint.dart";

Future<Map<String, dynamic>> fetchRemoteJson(Dio dio, Uri uri) async {
  final response = await getRemoteUri<Object>(dio, uri);
  final data = response.data;
  final Object? decoded = switch (data) {
    final String text => jsonDecode(text),
    final Map<String, dynamic> map => map,
    _ => throw RemoteContentException("Remote JSON response is not an object: $uri"),
  };
  if (decoded is! Map<String, dynamic>) {
    throw RemoteContentException("Remote JSON response is not an object: $uri");
  }
  return decoded;
}

Future<Response<T>> getRemoteUri<T>(
  Dio dio,
  Uri uri, {
  ResponseType responseType = ResponseType.plain,
}) async {
  try {
    return await dio.getUri<T>(uri, options: Options(responseType: responseType));
  } on DioException catch (exception) {
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
