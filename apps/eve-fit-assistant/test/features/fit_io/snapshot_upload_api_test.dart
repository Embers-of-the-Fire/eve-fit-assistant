@TestOn("vm")
library;

import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:efa_platform_client/efa_platform_client.dart";
import "package:efa_proto/fit_request.pb.dart";
import "package:efa_proto/fit_snapshot.pb.dart" show DamageProfile;
import "package:eve_fit_assistant/features/fit_io/snapshot_upload_api.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_test/flutter_test.dart";

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._onFetch);

  final Future<ResponseBody> Function(RequestOptions options, List<int> body) _onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        body.addAll(chunk);
      }
    }
    return _onFetch(options, body);
  }

  @override
  void close({bool force = false}) {}
}

const _origin = "https://api.efa-tech.dev";

FitUploadRequest _request() => FitUploadRequest(
  serverId: "Serenity",
  snapshotHash: "hash",
  fitName: "Test",
  lastModifiedMs: Int64(1),
  fit: FitState(
    shipTypeId: 12017,
    damageProfile: DamageProfile(em: 0.25, thermal: 0.25, kinetic: 0.25, explosive: 0.25),
  ),
);

/// Builds the injected transport: a fake adapter, optionally behind the same
/// bearer-attaching interceptor shape the platform session's authed Dio uses.
Dio _dioWith(
  Future<ResponseBody> Function(RequestOptions options, List<int> body) onFetch, {
  String? accessToken,
}) {
  final dio = Dio(BaseOptions())..httpClientAdapter = _FakeAdapter(onFetch);
  if (accessToken != null) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers["Authorization"] = "Bearer $accessToken";
          handler.next(options);
        },
      ),
    );
  }
  return dio;
}

void main() {
  test("submits a protobuf body through the authed dio and decodes the response", () async {
    RequestOptions? captured;
    List<int>? capturedBody;
    final dio = _dioWith((options, body) async {
      captured = options;
      capturedBody = body;
      return ResponseBody.fromString(
        jsonEncode({
          "postId": "post-1",
          "fitHash": "abc123",
          "alreadyExisted": true,
          "postUrl": "https://platform.efa-tech.dev/post/post-1",
        }),
        201,
        headers: {
          Headers.contentTypeHeader: ["application/json"],
        },
      );
    }, accessToken: "account-access-token");

    final response = await FitSnapshotUploadApi().submit(_request(), dio: dio, origin: _origin);

    expect(response.postId, "post-1");
    expect(response.fitHash, "abc123");
    expect(response.alreadyExisted, isTrue);
    expect(response.postUrl, "https://platform.efa-tech.dev/post/post-1");
    expect(response.origin, _origin);

    expect(captured?.path, "$_origin/platform/internal/posts");
    expect(captured?.method, "POST");
    // The bearer header arrives via the injected authed dio, not the API.
    expect(captured?.headers["Authorization"], "Bearer account-access-token");
    expect(captured?.contentType, "application/x-protobuf");
    final decoded = FitUploadRequest.fromBuffer(capturedBody!);
    expect(decoded.serverId, "Serenity");
    expect(decoded.fit.shipTypeId, 12017);
  });

  test("maps the worker error envelope to a typed exception", () async {
    final dio = _dioWith((options, body) async {
      return ResponseBody.fromBytes(
        Uint8List.fromList(
          utf8.encode(jsonEncode({"error": "snapshot_incomplete", "message": "not registered"})),
        ),
        409,
        headers: {
          Headers.contentTypeHeader: ["application/json"],
        },
      );
    });

    await expectLater(
      () => FitSnapshotUploadApi().submit(_request(), dio: dio, origin: _origin),
      throwsA(
        isA<FitUploadException>()
            .having((e) => e.code, "code", FitUploadErrorCode.snapshotIncomplete)
            .having((e) => e.message, "message", "not registered"),
      ),
    );
  });

  test("maps validation failures with the raw issues array", () async {
    const issues = [
      {"slot_type": "High", "index": 0, "severity": "Error", "kind": "ModuleState"},
    ];
    final dio = _dioWith((options, body) async {
      return ResponseBody.fromBytes(
        Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              "error": "validation_failed",
              "message": "fit failed engine validation",
              "issues": issues,
            }),
          ),
        ),
        422,
        headers: {
          Headers.contentTypeHeader: ["application/json"],
        },
      );
    });

    await expectLater(
      () => FitSnapshotUploadApi().submit(_request(), dio: dio, origin: _origin),
      throwsA(
        isA<FitUploadException>()
            .having((e) => e.code, "code", FitUploadErrorCode.validationFailed)
            .having((e) => e.message, "message", "fit failed engine validation")
            .having((e) => e.issues, "issues", issues),
      ),
    );
  });

  test("falls back to the status code when the 401 body is empty", () async {
    final dio = _dioWith((options, body) async {
      return ResponseBody.fromBytes(Uint8List(0), 401);
    });

    await expectLater(
      () => FitSnapshotUploadApi().submit(_request(), dio: dio, origin: _origin),
      throwsA(
        isA<FitUploadException>().having((e) => e.code, "code", FitUploadErrorCode.unauthorized),
      ),
    );
  });

  test("maps the ACL forbidden envelope to the forbidden code", () async {
    final dio = _dioWith((options, body) async {
      return ResponseBody.fromString(
        jsonEncode({"error": "forbidden", "message": "permission denied"}),
        403,
        headers: {
          Headers.contentTypeHeader: ["application/json"],
        },
      );
    });

    await expectLater(
      () => FitSnapshotUploadApi().submit(_request(), dio: dio, origin: _origin),
      throwsA(
        isA<FitUploadException>()
            .having((e) => e.code, "code", FitUploadErrorCode.forbidden)
            .having((e) => e.message, "message", "permission denied"),
      ),
    );
  });

  test("falls back to the forbidden code when the 403 body is empty", () async {
    final dio = _dioWith((options, body) async {
      return ResponseBody.fromBytes(Uint8List(0), 403);
    });

    await expectLater(
      () => FitSnapshotUploadApi().submit(_request(), dio: dio, origin: _origin),
      throwsA(
        isA<FitUploadException>().having((e) => e.code, "code", FitUploadErrorCode.forbidden),
      ),
    );
  });

  test("falls back to the status code when the body is a proxy HTML page", () async {
    final dio = _dioWith((options, body) async {
      return ResponseBody.fromString(
        "<html><body>404 Not Found</body></html>",
        404,
        headers: {
          Headers.contentTypeHeader: ["text/html"],
        },
      );
    });

    await expectLater(
      () => FitSnapshotUploadApi().submit(_request(), dio: dio, origin: _origin),
      throwsA(isA<FitUploadException>().having((e) => e.code, "code", FitUploadErrorCode.notFound)),
    );
  });

  test("falls back to the status code when the JSON body has no error field", () async {
    final dio = _dioWith((options, body) async {
      return ResponseBody.fromString(
        jsonEncode({"message": "token expired"}),
        401,
        headers: {
          Headers.contentTypeHeader: ["application/json"],
        },
      );
    });

    await expectLater(
      () => FitSnapshotUploadApi().submit(_request(), dio: dio, origin: _origin),
      throwsA(
        isA<FitUploadException>()
            .having((e) => e.code, "code", FitUploadErrorCode.unauthorized)
            .having((e) => e.message, "message", "token expired"),
      ),
    );
  });

  test("maps connection failures to the network code", () async {
    final dio = _dioWith((options, body) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: "unreachable",
      );
    });

    await expectLater(
      () => FitSnapshotUploadApi().submit(_request(), dio: dio, origin: _origin),
      throwsA(isA<FitUploadException>().having((e) => e.code, "code", FitUploadErrorCode.network)),
    );
  });

  test("maps a wrapped account-api failure without status to the network code", () async {
    // The session interceptor wraps a failed token refresh in a bare
    // DioException; an AccountApiException without a status code means the
    // refresh request never received a response.
    final dio = _dioWith((options, body) async {
      throw DioException(requestOptions: options, error: const AccountApiException(null));
    });

    await expectLater(
      () => FitSnapshotUploadApi().submit(_request(), dio: dio, origin: _origin),
      throwsA(isA<FitUploadException>().having((e) => e.code, "code", FitUploadErrorCode.network)),
    );
  });

  test("surfaces a wrapped account-api failure with a status", () async {
    final dio = _dioWith((options, body) async {
      throw DioException(
        requestOptions: options,
        error: const AccountApiException(429, "rate_limited", "slow down"),
      );
    });

    await expectLater(
      () => FitSnapshotUploadApi().submit(_request(), dio: dio, origin: _origin),
      throwsA(
        isA<FitUploadException>()
            .having((e) => e.code, "code", FitUploadErrorCode.unexpected)
            .having(
              (e) => e.message,
              "message",
              "AccountApiException(429, rate_limited: slow down)",
            ),
      ),
    );
  });

  test("keeps the type and cause for unknown dio failures", () async {
    final dio = _dioWith((options, body) async {
      throw DioException(requestOptions: options, error: StateError("boom"));
    });

    await expectLater(
      () => FitSnapshotUploadApi().submit(_request(), dio: dio, origin: _origin),
      throwsA(
        isA<FitUploadException>()
            .having((e) => e.code, "code", FitUploadErrorCode.unexpected)
            .having((e) => e.message, "message", contains("boom")),
      ),
    );
  });
}
