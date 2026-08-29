@TestOn("vm")
library;

import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:efa_platform_client/efa_platform_client.dart";
import "package:flutter_test/flutter_test.dart";

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._onFetch);

  final Future<ResponseBody> Function(RequestOptions options) _onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => _onFetch(options);

  @override
  void close({bool force = false}) {}
}

/// In-memory [PlatformSessionStore]; [writeError] simulates a secure-storage
/// failure that leaves the stored session untouched (atomic single write).
class _MemoryStore implements PlatformSessionStore {
  StoredPlatformSession? session;
  Exception? writeError;

  @override
  Future<StoredPlatformSession?> read() async => session;

  @override
  Future<void> write(StoredPlatformSession value) async {
    final error = writeError;
    if (error != null) throw error;
    session = value;
  }

  @override
  Future<void> clear() async => session = null;
}

String _jwt(String subject) {
  String segment(Object value) => base64Url.encode(utf8.encode(jsonEncode(value)));
  return "${segment({"alg": "HS256", "typ": "JWT"})}.${segment({"sub": subject, "tv": 0})}.sig";
}

Map<String, dynamic> _pair(String suffix, {String? subject}) => {
  "accessToken": _jwt(subject ?? "user-$suffix"),
  "refreshToken": "refresh-$suffix",
  "expiresIn": 900,
};

/// A rotation result for the seeded account: the access-token subject stays
/// the account's user id (`user-old`).
Map<String, dynamic> _rotatedPair(String refreshSuffix) =>
    _pair(refreshSuffix, subject: "user-old");

ResponseBody _json(Object body, [int status = 200, Map<String, List<String>>? headers]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ["application/json"],
        ...?headers,
      },
    );

const _invalidToken = {"error": "invalid_token", "message": "missing or invalid access token"};

/// Scriptable transport for the auth endpoints plus arbitrary other paths
/// (see [authedHandler]).
class _Server {
  int refreshCalls = 0;
  Exception? refreshThrow;
  ResponseBody Function()? refreshResponse;
  ResponseBody Function()? loginResponse;
  String? loggedOutRefreshToken;
  String? deregisterBearer;
  String? deregisterPassword;

  /// Handles requests that are not auth-endpoint calls (the `authed` escape
  /// hatch, public reads).
  Future<ResponseBody> Function(RequestOptions options)? authedHandler;

  Future<ResponseBody> fetch(RequestOptions options) async {
    final path = options.path;
    if (path.endsWith("/platform/auth/login")) {
      return loginResponse!();
    }
    if (path.endsWith("/platform/auth/refresh")) {
      refreshCalls++;
      final error = refreshThrow;
      if (error != null) throw error;
      return refreshResponse!();
    }
    if (path.endsWith("/platform/auth/logout")) {
      loggedOutRefreshToken = (options.data as Map<String, dynamic>)["refreshToken"] as String;
      return _json({"ok": true});
    }
    if (path.endsWith("/platform/auth/deregister")) {
      deregisterBearer = options.headers["Authorization"] as String?;
      deregisterPassword = (options.data as Map<String, dynamic>)["password"] as String?;
      return _json({"ok": true});
    }
    final handler = authedHandler;
    if (handler != null) return handler(options);
    throw StateError("unexpected request: $path");
  }
}

void main() {
  const origin = "https://test.invalid";
  late _MemoryStore store;
  late _Server server;
  int authRequiredCalls = 0;

  PlatformSession session({
    bool trackAuthRequired = true,
    String? cfAccessClientId,
    String? cfAccessClientSecret,
  }) => PlatformSession(
    origin: origin,
    store: store,
    dioFactory: () => Dio(BaseOptions())..httpClientAdapter = _FakeAdapter(server.fetch),
    cfAccessClientId: cfAccessClientId,
    cfAccessClientSecret: cfAccessClientSecret,
    onAuthRequired: trackAuthRequired ? () => authRequiredCalls++ : null,
  );

  StoredPlatformSession storedSession({bool expired = false}) => StoredPlatformSession(
    accessToken: _jwt("user-old"),
    refreshToken: "refresh-old",
    expiresAt: expired
        ? DateTime.now().subtract(const Duration(minutes: 5))
        : DateTime.now().add(const Duration(minutes: 10)),
    email: "capsuleer@example.com",
    userId: "user-old",
  );

  void seedSignedIn({bool expired = false}) => store.session = storedSession(expired: expired);

  setUp(() {
    store = _MemoryStore();
    server = _Server()..refreshResponse = () => _json(_rotatedPair("boot"));
    authRequiredCalls = 0;
  });

  group("store contract", () {
    test("write/read/clear round-trips through the in-memory store", () async {
      final record = storedSession();
      await store.write(record);
      expect((await store.read())?.refreshToken, "refresh-old");
      await store.clear();
      expect(await store.read(), isNull);
    });
  });

  group("cold start", () {
    test("starts signed out without a stored session", () async {
      final s = session();
      await s.ready;

      expect(s.me, isNull);
      expect(server.refreshCalls, 0);
      expect(await s.identity.first, isNull);
    });

    test("startup refresh rotates the stored pair once per cold start", () async {
      seedSignedIn();
      final s = session();
      await s.ready;

      expect(s.me, const PlatformIdentity(userId: "user-old", email: "capsuleer@example.com"));
      expect(server.refreshCalls, 1);
      expect(store.session?.refreshToken, "refresh-boot");
    });

    test("startup refresh keeps the session when the server is unreachable", () async {
      seedSignedIn();
      server.refreshThrow = Exception("offline");
      final s = session();
      await s.ready;

      expect(s.me, isNotNull);
      expect(store.session?.refreshToken, "refresh-old");
    });

    test("startup refresh keeps the stored session when persisting the rotation fails", () async {
      seedSignedIn();
      store.writeError = Exception("secure storage unavailable");
      final s = session();
      await s.ready;

      // The rotation succeeded server-side but could not be persisted: the
      // stored pair stays intact (no partial session state) and the session
      // keeps working on it.
      expect(s.me, isNotNull);
      expect(server.refreshCalls, 1);
      expect(store.session?.refreshToken, "refresh-old");
    });

    test("startup refresh signs out when the refresh token is dead", () async {
      seedSignedIn();
      server.refreshResponse = () => _json(_invalidToken, 401);
      final s = session();
      await s.ready;

      expect(s.me, isNull);
      expect(store.session, isNull);
      // No login redirect at cold start: nothing is in flight that it would
      // recover.
      expect(authRequiredCalls, 0);
    });

    test("startup refresh keeps the stored session when the rotated pair has no subject", () async {
      seedSignedIn();
      server.refreshResponse = () =>
          _json({"accessToken": "not-a-jwt", "refreshToken": "refresh-bad", "expiresIn": 900});
      final s = session();
      await s.ready;

      // The malformed pair is never persisted: the stored session stays
      // intact and the state keeps identifying the prior account.
      expect(s.me?.userId, "user-old");
      expect(server.refreshCalls, 1);
      expect(store.session?.refreshToken, "refresh-old");
    });

    test(
      "startup refresh keeps the stored session when the rotated pair subject mismatches",
      () async {
        seedSignedIn();
        server.refreshResponse = () => _json(_pair("other"));
        final s = session();
        await s.ready;

        // A pair identifying another account must not replace the stored
        // access token while the state still identifies the prior account.
        expect(s.me?.userId, "user-old");
        expect(server.refreshCalls, 1);
        expect(store.session?.refreshToken, "refresh-old");
      },
    );
  });

  group("auth flows", () {
    test("login stores the session and publishes the identity", () async {
      server.loginResponse = () => _json(_pair("1"));
      final s = session();
      await s.ready;
      final identities = <PlatformIdentity?>[];
      final sub = s.identity.listen(identities.add);

      await s.login(email: "capsuleer@example.com", password: "secret-pw");
      // Identity events are delivered asynchronously.
      await Future<void>.delayed(Duration.zero);

      expect(s.me, const PlatformIdentity(userId: "user-1", email: "capsuleer@example.com"));
      expect(store.session?.refreshToken, "refresh-1");
      expect(identities, [
        isNull,
        const PlatformIdentity(userId: "user-1", email: "capsuleer@example.com"),
      ]);
      await sub.cancel();
    });

    test("a login failure leaves the session signed out", () async {
      server.loginResponse = () =>
          _json({"error": "invalid_credentials", "message": "invalid email or password"}, 401);
      final s = session();
      await s.ready;

      await expectLater(
        () => s.login(email: "a@b.c", password: "wrong"),
        throwsA(isA<AccountApiException>()),
      );
      expect(s.me, isNull);
      expect(store.session, isNull);
    });

    test("login rejects a token pair without a usable JWT subject", () async {
      seedSignedIn();
      server.loginResponse = () =>
          _json({"accessToken": "not-a-jwt", "refreshToken": "refresh-bad", "expiresIn": 900});
      final s = session();
      await s.ready;

      await expectLater(
        () => s.login(email: "capsuleer@example.com", password: "secret-pw"),
        throwsA(isA<AccountApiException>()),
      );

      // The malformed pair is never stored and the identity is cleared.
      expect(store.session, isNull);
      expect(s.me, isNull);
    });

    test("logout revokes the stored refresh token and clears the identity", () async {
      server.loginResponse = () => _json(_pair("1"));
      final s = session();
      await s.ready;
      await s.login(email: "capsuleer@example.com", password: "secret-pw");

      await s.logout();

      expect(server.loggedOutRefreshToken, "refresh-1");
      expect(s.me, isNull);
      expect(store.session, isNull);
    });

    test("deregister reuses a valid access token without refreshing", () async {
      server.loginResponse = () => _json(_pair("1"));
      final s = session();
      await s.ready;
      await s.login(email: "capsuleer@example.com", password: "secret-pw");

      await s.deregister(password: "secret-pw");

      expect(server.refreshCalls, 0);
      expect(server.deregisterBearer, "Bearer ${_jwt("user-1")}");
      expect(server.deregisterPassword, "secret-pw");
      expect(s.me, isNull);
      expect(store.session, isNull);
    });
  });

  group("expiry refresh", () {
    /// Drains the startup refresh, then re-seeds an expired pair so the
    /// refresh counter only measures the operation under test.
    Future<PlatformSession> sessionWithExpiredPair() async {
      seedSignedIn(expired: true);
      final s = session();
      await s.ready;
      server.refreshCalls = 0;
      store.session = storedSession(expired: true);
      return s;
    }

    test("deregister refreshes an expired access token and stores the rotated pair", () async {
      final s = await sessionWithExpiredPair();
      server.refreshResponse = () => _json(_rotatedPair("new"));

      await s.deregister(password: "secret-pw");

      // The operation rotates exactly once; a duplicate refresh would rotate
      // the refresh token twice and could invalidate the stored pair. A
      // successful deregistration clears the rotated pair again.
      expect(server.refreshCalls, 1);
      expect(server.deregisterBearer, "Bearer ${_jwt("user-old")}");
      expect(store.session, isNull);
    });

    test("concurrent operations are serialized and rotate the pair only once", () async {
      final s = await sessionWithExpiredPair();
      server.refreshResponse = () => _json(_rotatedPair("new"));

      // Both calls enter the refresh path while the stored pair is expired.
      // The second one must observe the rotated pair on its re-read inside
      // the critical section instead of refreshing again with the same (now
      // server-side dead) refresh token.
      await Future.wait([s.deregister(password: "secret-pw"), s.deregister(password: "secret-pw")]);

      expect(server.refreshCalls, 1);
      expect(store.session, isNull);
    });

    test("a refresh rejected as invalid clears the session and fires onAuthRequired", () async {
      final s = await sessionWithExpiredPair();
      server.refreshResponse = () => _json(_invalidToken, 401);

      await expectLater(
        () => s.deregister(password: "secret-pw"),
        throwsA(isA<PlatformAuthRequiredException>()),
      );
      expect(s.me, isNull);
      expect(store.session, isNull);
      expect(authRequiredCalls, 1);
    });

    test("expiry refresh rejects a rotated pair without a usable JWT subject", () async {
      final s = await sessionWithExpiredPair();
      server.refreshResponse = () =>
          _json({"accessToken": "not-a-jwt", "refreshToken": "refresh-bad", "expiresIn": 900});

      await expectLater(
        () => s.deregister(password: "secret-pw"),
        throwsA(isA<PlatformAuthRequiredException>()),
      );

      // The malformed pair is neither stored nor returned, and the doomed
      // session (its refresh token was rotated server-side) is cleared.
      expect(server.refreshCalls, 1);
      expect(server.deregisterBearer, isNull);
      expect(store.session, isNull);
    });

    test("expiry refresh rejects a rotated pair with a mismatched JWT subject", () async {
      final s = await sessionWithExpiredPair();
      server.refreshResponse = () => _json(_pair("other"));

      await expectLater(
        () => s.deregister(password: "secret-pw"),
        throwsA(isA<PlatformAuthRequiredException>()),
      );

      // A pair identifying another account is neither stored nor returned,
      // and the doomed session is cleared like a rejected refresh.
      expect(server.refreshCalls, 1);
      expect(server.deregisterBearer, isNull);
      expect(store.session, isNull);
    });
  });

  group("createComment", () {
    test("posts the body with a valid access token and decodes the comment", () async {
      seedSignedIn();
      RequestOptions? captured;
      server.authedHandler = (options) async {
        captured = options;
        return _json({
          "commentId": "c-1",
          "postId": "p-1",
          "authorId": "user-old",
          "authorDeleted": false,
          "body": "**hello**",
          "createdAt": "2026-08-28T00:00:00.000Z",
        }, 201);
      };
      final s = session();
      await s.ready;

      final comment = await s.createComment(postId: "p-1", body: "**hello**");

      expect(captured?.path, "$origin/platform/internal/posts/p-1/comments");
      expect(captured?.method, "POST");
      expect(captured?.headers["Authorization"], "Bearer ${_jwt("user-old")}");
      expect((captured?.data as Map<String, dynamic>)["body"], "**hello**");
      expect(comment.commentId, "c-1");
      expect(comment.authorId, "user-old");
      expect(comment.authorDeleted, isFalse);
      expect(comment.body, "**hello**");
    });

    test("maps a 403 to a PlatformApiException with the envelope code", () async {
      seedSignedIn();
      server.authedHandler = (options) async =>
          _json({"error": "forbidden", "message": "missing permission: comment:create"}, 403);
      final s = session();
      await s.ready;

      await expectLater(
        () => s.createComment(postId: "p-1", body: "hi"),
        throwsA(
          isA<PlatformApiException>()
              .having((e) => e.statusCode, "statusCode", 403)
              .having((e) => e.code, "code", "forbidden"),
        ),
      );
    });

    test("without a session throws PlatformAuthRequiredException", () async {
      final s = session();
      await s.ready;

      await expectLater(
        () => s.createComment(postId: "p-1", body: "hi"),
        throwsA(isA<PlatformAuthRequiredException>()),
      );
      expect(authRequiredCalls, 1);
    });
  });

  group("authed", () {
    const authedPath = "$origin/platform/internal/authed";

    test("attaches a valid access token without refreshing", () async {
      seedSignedIn();
      String? authorization;
      server.authedHandler = (options) async {
        authorization = options.headers["Authorization"] as String?;
        return _json({"ok": true});
      };
      final s = session();
      await s.ready;

      final data = await s.authed(
        (dio) async => (await dio.get<Map<String, dynamic>>(authedPath)).data,
      );

      expect(data, {"ok": true});
      expect(authorization, "Bearer ${_jwt("user-old")}");
      // Only the cold-start rotation ran.
      expect(server.refreshCalls, 1);
    });

    test("refreshes an expired access token before the request", () async {
      seedSignedIn(expired: true);
      String? authorization;
      server.authedHandler = (options) async {
        authorization = options.headers["Authorization"] as String?;
        return _json({"ok": true});
      };
      final s = session();
      await s.ready;
      server.refreshCalls = 0;
      store.session = storedSession(expired: true);
      server.refreshResponse = () => _json(_rotatedPair("new"));

      await s.authed((dio) => dio.get<Map<String, dynamic>>(authedPath));

      expect(server.refreshCalls, 1);
      expect(authorization, "Bearer ${_jwt("user-old")}");
      expect(store.session?.refreshToken, "refresh-new");
    });

    test("a 401 forces one rotation and retries the request once", () async {
      seedSignedIn();
      final seen = <String?>[];
      server
        ..authedHandler = (options) async {
          seen.add(options.headers["Authorization"] as String?);
          // Reject the pre-rotation token, accept the rotated one.
          return seen.length == 1 ? _json(_invalidToken, 401) : _json({"ok": true});
        }
        ..refreshResponse = () => _json(_rotatedPair("new"));
      final s = session();
      await s.ready;
      // Discount the cold-start rotation.
      server.refreshCalls = 0;

      final data = await s.authed(
        (dio) async => (await dio.get<Map<String, dynamic>>(authedPath)).data,
      );

      expect(data, {"ok": true});
      expect(server.refreshCalls, 1);
      expect(seen, ["Bearer ${_jwt("user-old")}", "Bearer ${_jwt("user-old")}"]);
      expect(store.session?.refreshToken, "refresh-new");
    });

    test("a 401 with a rejected refresh clears the session and throws", () async {
      seedSignedIn();
      server
        ..authedHandler = ((options) async => _json(_invalidToken, 401))
        ..refreshResponse = () => _json(_invalidToken, 401);
      final s = session();
      await s.ready;

      await expectLater(
        () => s.authed((dio) => dio.get<Map<String, dynamic>>(authedPath)),
        throwsA(isA<PlatformAuthRequiredException>()),
      );
      expect(store.session, isNull);
      expect(s.me, isNull);
      expect(authRequiredCalls, 1);
    });

    test("without a session the request never leaves the client", () async {
      var requests = 0;
      server.authedHandler = (options) async {
        requests++;
        return _json({"ok": true});
      };
      final s = session();
      await s.ready;

      await expectLater(
        () => s.authed((dio) => dio.get<Map<String, dynamic>>(authedPath)),
        throwsA(isA<PlatformAuthRequiredException>()),
      );
      expect(requests, 0);
      expect(authRequiredCalls, 1);
    });

    test("onAuthRequired is throttled per signed-out stretch and reset by login", () async {
      seedSignedIn();
      server
        ..authedHandler = ((options) async => _json(_invalidToken, 401))
        ..refreshResponse = () => _json(_invalidToken, 401);
      final s = session();
      await s.ready;

      // A burst of failing requests triggers one navigation, not many.
      for (var i = 0; i < 3; i++) {
        await expectLater(
          () => s.authed((dio) => dio.get<Map<String, dynamic>>(authedPath)),
          throwsA(isA<PlatformAuthRequiredException>()),
        );
      }
      expect(authRequiredCalls, 1);

      // The next successful login rearms the hook.
      server.loginResponse = () => _json(_pair("1"));
      await s.login(email: "capsuleer@example.com", password: "secret-pw");
      server.refreshResponse = () => _json(_invalidToken, 401);
      await expectLater(
        () => s.authed((dio) => dio.get<Map<String, dynamic>>(authedPath)),
        throwsA(isA<PlatformAuthRequiredException>()),
      );
      expect(authRequiredCalls, 2);
    });
  });

  group("public reads", () {
    test("never attach credentials or trigger auth logic", () async {
      seedSignedIn();
      String? authorization;
      server.authedHandler = (options) async {
        authorization = options.headers["Authorization"] as String?;
        return _json({
          "postId": "p",
          "authorId": null,
          "authorDeleted": true,
          "fitHash": "abc",
          "createdAt": "2026-08-19T00:00:00.000Z",
          "commentCount": 0,
        });
      };
      final s = session();
      await s.ready;

      final record = await s.getPost("p");

      expect(record?.fitHash, "abc");
      expect(authorization, isNull);
      expect(authRequiredCalls, 0);
    });
  });

  group("Cloudflare Access service token", () {
    test("rides on authed requests and public reads, not just auth calls", () async {
      seedSignedIn();
      final seen = <String, RequestOptions>{};
      server.authedHandler = (options) async {
        seen[options.path] = options;
        if (options.path.endsWith("/posts/p")) {
          return _json({
            "postId": "p",
            "authorId": null,
            "authorDeleted": true,
            "fitHash": "abc",
            "createdAt": "2026-08-19T00:00:00.000Z",
            "commentCount": 0,
          });
        }
        return _json({"ok": true});
      };
      final s = session(cfAccessClientId: "cf-id-1.access", cfAccessClientSecret: "cf-secret-1");
      await s.ready;

      await s.authed(
        (dio) async => (await dio.get<Map<String, dynamic>>("$origin/platform/internal/x")).data,
      );
      await s.getPost("p");

      for (final options in seen.values) {
        expect(options.headers["CF-Access-Client-Id"], "cf-id-1.access");
        expect(options.headers["CF-Access-Client-Secret"], "cf-secret-1");
      }
      expect(seen, hasLength(2));
    });

    test("is absent from every client when not configured", () async {
      seedSignedIn();
      final seen = <RequestOptions>[];
      server.authedHandler = (options) async {
        seen.add(options);
        return _json({"ok": true});
      };
      final s = session();
      await s.ready;

      await s.authed(
        (dio) async => (await dio.get<Map<String, dynamic>>("$origin/platform/internal/x")).data,
      );

      expect(seen.single.headers["CF-Access-Client-Id"], isNull);
      expect(seen.single.headers["CF-Access-Client-Secret"], isNull);
    });
  });
}
