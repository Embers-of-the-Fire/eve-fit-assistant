@TestOn("vm")
library;

import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
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

FitSnapshotUploadApi _apiWith(
  Future<ResponseBody> Function(RequestOptions options, List<int> body) onFetch,
) => FitSnapshotUploadApi(dio: Dio(BaseOptions())..httpClientAdapter = _FakeAdapter(onFetch));

void main() {
  test("submits a protobuf body with bearer auth and decodes the response", () async {
    RequestOptions? captured;
    List<int>? capturedBody;
    final api = _apiWith((options, body) async {
      captured = options;
      capturedBody = body;
      return ResponseBody.fromString(
        jsonEncode({"postId": "post-1", "fitHash": "abc123", "alreadyExisted": true}),
        201,
        headers: {
          Headers.contentTypeHeader: ["application/json"],
        },
      );
    });

    final response = await api.submit(_request(), token: "secret-token");

    expect(response.postId, "post-1");
    expect(response.fitHash, "abc123");
    expect(response.alreadyExisted, isTrue);

    expect(captured?.path, "https://api.efa-tech.dev/platform/internal/posts");
    expect(captured?.method, "POST");
    expect(captured?.headers["Authorization"], "Bearer secret-token");
    expect(captured?.contentType, "application/x-protobuf");
    final decoded = FitUploadRequest.fromBuffer(capturedBody!);
    expect(decoded.serverId, "Serenity");
    expect(decoded.fit.shipTypeId, 12017);
  });

  test("maps the worker error envelope to a typed exception", () async {
    final api = _apiWith((options, body) async {
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
      () => api.submit(_request(), token: "t"),
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
    final api = _apiWith((options, body) async {
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
      () => api.submit(_request(), token: "t"),
      throwsA(
        isA<FitUploadException>()
            .having((e) => e.code, "code", FitUploadErrorCode.validationFailed)
            .having((e) => e.message, "message", "fit failed engine validation")
            .having((e) => e.issues, "issues", issues),
      ),
    );
  });

  test("falls back to the status code when the 401 body is empty", () async {
    final api = _apiWith((options, body) async {
      return ResponseBody.fromBytes(Uint8List(0), 401);
    });

    await expectLater(
      () => api.submit(_request(), token: "t"),
      throwsA(
        isA<FitUploadException>().having((e) => e.code, "code", FitUploadErrorCode.unauthorized),
      ),
    );
  });

  test("falls back to the status code when the body is a proxy HTML page", () async {
    final api = _apiWith((options, body) async {
      return ResponseBody.fromString(
        "<html><body>404 Not Found</body></html>",
        404,
        headers: {
          Headers.contentTypeHeader: ["text/html"],
        },
      );
    });

    await expectLater(
      () => api.submit(_request(), token: "t"),
      throwsA(isA<FitUploadException>().having((e) => e.code, "code", FitUploadErrorCode.notFound)),
    );
  });

  test("falls back to the status code when the JSON body has no error field", () async {
    final api = _apiWith((options, body) async {
      return ResponseBody.fromString(
        jsonEncode({"message": "token expired"}),
        401,
        headers: {
          Headers.contentTypeHeader: ["application/json"],
        },
      );
    });

    await expectLater(
      () => api.submit(_request(), token: "t"),
      throwsA(
        isA<FitUploadException>()
            .having((e) => e.code, "code", FitUploadErrorCode.unauthorized)
            .having((e) => e.message, "message", "token expired"),
      ),
    );
  });

  test("maps connection failures to the network code", () async {
    final api = _apiWith((options, body) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: "unreachable",
      );
    });

    await expectLater(
      () => api.submit(_request(), token: "t"),
      throwsA(isA<FitUploadException>().having((e) => e.code, "code", FitUploadErrorCode.network)),
    );
  });

  test("builds the public by-hash URL", () {
    expect(
      FitSnapshotUploadApi.byHashUrl("abc123"),
      "https://api.efa-tech.dev/platform/internal/fits/abc123/snapshot",
    );
  });
}
