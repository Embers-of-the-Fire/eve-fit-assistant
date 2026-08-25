import "dart:async";

import "package:dio/dio.dart";
import "package:efa_platform_client/src/auth_client.dart";
import "package:efa_platform_client/src/jwt.dart";
import "package:efa_platform_client/src/platform_client.dart";
import "package:efa_platform_client/src/session_store.dart";
import "package:efa_proto/fit_request.pb.dart";
import "package:efa_proto/fit_snapshot.pb.dart";

/// Production origin of the platform API (`worker/efa-platform-api`): auth
/// endpoints are mounted at `/platform/auth`, public reads at
/// `/platform/internal`.
const platformApiProductionOrigin = "https://api.efa-tech.dev";

/// Refresh the access token when it expires within this window.
const Duration _refreshSkew = Duration(minutes: 1);

/// What the outside world knows about the signed-in user.
///
/// Reserved placeholder: derived locally (JWT subject + cached email); no
/// server `/me` endpoint exists yet and the shape may change when one lands.
final class PlatformIdentity {
  const PlatformIdentity({required this.userId, required this.email});

  final String userId;
  final String email;

  @override
  bool operator ==(Object other) =>
      other is PlatformIdentity && other.userId == userId && other.email == email;

  @override
  int get hashCode => Object.hash(userId, email);

  @override
  String toString() => "PlatformIdentity($userId, $email)";
}

/// Thrown when a request needs auth but no valid session exists (never
/// logged in, refresh rejected, or the session was revoked server-side).
/// The session's `onAuthRequired` hook fires before this propagates.
final class PlatformAuthRequiredException implements Exception {
  const PlatformAuthRequiredException([this.message = "a valid session is required"]);

  final String message;

  @override
  String toString() => "PlatformAuthRequiredException($message)";
}

/// Simple Future-based mutex for serializing session mutations.
class _Mutex {
  Future<void> _last = Future.value();

  Future<T> synchronized<T>(Future<T> Function() fn) {
    final prev = _last;
    final next = prev.then((_) => fn());
    _last = next.then((_) => null, onError: (_) => null);
    return next;
  }
}

/// United facade over the platform API: account auth flows, the whole token
/// lifecycle (storage, expiry tracking, mutex-serialized refresh, rotation
/// replay, 401 retry, session clearing), and the public read endpoints.
///
/// App code never touches an access token: everything token-shaped is
/// package-internal. The session record lives behind [PlatformSessionStore];
/// the cold-start rotation (offline-tolerant, with a subject-mismatch guard)
/// starts on construction and runs once per process, keeping the 30-day
/// refresh token alive for active users and dropping stale sessions early.
class PlatformSession {
  PlatformSession({
    required this.origin,
    required this._store,
    Dio Function()? dioFactory,
    String? cfAccessClientId,
    String? cfAccessClientSecret,
    this._onAuthRequired,
    this._emailLocale,
  }) {
    final createDio = dioFactory ?? Dio.new;
    // The Access gate protecting the preview environment challenges every
    // path on the origin, not just /platform/auth: the service token must
    // ride on public reads and authed uploads too.
    Dio scopedDio() {
      final dio = createDio();
      final interceptor = cfAccessServiceTokenInterceptor(cfAccessClientId, cfAccessClientSecret);
      if (interceptor != null) {
        dio.interceptors.add(interceptor);
      }
      return dio;
    }

    _authClient = AccountApiClient(
      origin: origin,
      cfAccessClientId: cfAccessClientId,
      cfAccessClientSecret: cfAccessClientSecret,
      dio: createDio(),
    );
    _publicClient = PlatformApiClient(origin: origin, dio: scopedDio());
    _authedDio = scopedDio()..interceptors.add(_AuthInterceptor(this));
    // Eagerly start the cold-start load/rotation (errors are contained in
    // [_ready]; the session simply reads as signed out).
    unawaited(_ready);
  }

  final PlatformSessionStore _store;
  final void Function()? _onAuthRequired;
  final String? Function()? _emailLocale;

  /// The platform API origin this session talks to (already resolved,
  /// including any developer-mode override); authenticated uploads build
  /// their URL from it.
  final String origin;
  late final AccountApiClient _authClient;
  late final PlatformApiClient _publicClient;
  late final Dio _authedDio;

  late final Future<void> _ready = _initialize();

  /// Completes when the cold-start load and one-time rotation has settled
  /// (never throws; a failure reads as signed out, like a missing session).
  Future<void> get ready => _ready;

  final _Mutex _mutex = _Mutex();

  PlatformIdentity? _identity;
  final _identityListeners = <void Function(PlatformIdentity?)>{};

  /// Whether the `onAuthRequired` hook already fired for the current
  /// signed-out stretch; reset on the next successful login so a burst of
  /// failing requests triggers one navigation, not many.
  bool _authRequiredFired = false;

  // ---- state ----

  /// The signed-in identity, or null when signed out. Null until the stored
  /// session (if any) has been loaded and validated at cold start.
  PlatformIdentity? get me => _identity;

  /// Identity changes as a stream; each listener first receives the
  /// post-cold-start value (like [me] once [ready] has completed), then
  /// every subsequent change.
  Stream<PlatformIdentity?> get identity => Stream.multi((controller) async {
    await _ready;
    controller.addSync(_identity);
    void listener(PlatformIdentity? value) => controller.add(value);
    _identityListeners.add(listener);
    controller.onCancel = () => _identityListeners.remove(listener);
  }, isBroadcast: true);

  void _setIdentity(PlatformIdentity? value) {
    if (value == _identity) return;
    _identity = value;
    for (final listener in List.of(_identityListeners)) {
      listener(value);
    }
  }

  // ---- auth flows: no tokens cross the boundary ----

  /// `POST /login`. Throws [AccountApiException] on failure; the UI maps
  /// `email_unverified` to the verification flow.
  Future<void> login({required String email, required String password}) async {
    final pair = await _authClient.login(email: email, password: password);
    await _acceptTokenPair(email, pair);
  }

  /// `POST /signup`: creates the pending account and sends the verification
  /// code. Also used to resend the code for an already-pending address.
  Future<void> signup({required String email, required String password}) =>
      _authClient.signup(email: email, password: password, locale: _emailLocale?.call());

  /// `POST /signup/resend`: resends the verification code for a pending
  /// account without a password (the verification step may be reached from
  /// the login redirect, where the password was never collected).
  Future<void> resendSignupCode({required String email}) =>
      _authClient.signupResend(email: email, locale: _emailLocale?.call());

  /// `POST /verify-email`: activates the pending account and signs in.
  Future<void> verifyEmail({required String email, required String code}) async {
    final pair = await _authClient.verifyEmail(email: email, code: code);
    await _acceptTokenPair(email, pair);
  }

  /// `POST /reset-password`: sends a reset code when the address belongs to
  /// an active account (the response never reveals which).
  Future<void> requestPasswordReset({required String email}) =>
      _authClient.resetPassword(email: email, locale: _emailLocale?.call());

  /// `POST /reset-password/confirm`: sets the new password and signs in with
  /// the freshly issued pair (all previous sessions are revoked server-side).
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final pair = await _authClient.resetPasswordConfirm(
      email: email,
      code: code,
      newPassword: newPassword,
    );
    await _acceptTokenPair(email, pair);
  }

  /// `POST /logout` (best-effort), then clears the local session.
  Future<void> logout() => _mutex.synchronized(() async {
    final session = await _store.read();
    if (session != null) {
      try {
        await _authClient.logout(refreshToken: session.refreshToken);
      } on Object {
        // Logout stays local: the refresh token dies with its 30-day TTL.
      }
    }
    await _clearSessionLocked();
  });

  /// `POST /deregister` with a fresh access token plus password
  /// re-authentication, then clears the local session.
  Future<void> deregister({required String password}) async {
    final accessToken = await _requireValidAccessToken();
    await _authClient.deregister(accessToken: accessToken, password: password);
    await _clearSession();
  }

  /// `POST /account` with a fresh access token: identity plus the account's
  /// ACL roles and their resolved permission tokens (see `packages/efa_acl`).
  Future<PlatformAccountInfo> accountInfo() async {
    final accessToken = await _requireValidAccessToken();
    return _authClient.account(accessToken: accessToken);
  }

  // ---- public reads (no auth involved) ----

  /// Cursor-paginated post list. [limit] is clamped server-side to 1..50
  /// (default 20).
  Future<PostListPage> listPosts({String? cursor, int? limit, String? locale}) =>
      _publicClient.listPosts(cursor: cursor, limit: limit, locale: locale);

  /// The post record; null when the post does not exist.
  Future<PostRecord?> getPost(String postId) => _publicClient.getPost(postId);

  /// The stored snapshot behind a post; null when the post does not exist.
  Future<FitSnapshot?> getPostSnapshot(String postId) => _publicClient.getPostSnapshot(postId);

  /// The stored snapshot addressed directly by fit hash; null when the fit
  /// does not exist.
  Future<FitSnapshot?> getFitSnapshot(String fitHash) => _publicClient.getFitSnapshot(fitHash);

  /// The stored canonical fit state addressed directly by fit hash; null
  /// when the fit does not exist.
  Future<FitState?> getFitState(String fitHash) => _publicClient.getFitState(fitHash);

  /// The thread list of a post (stub; currently always empty).
  Future<List<ThreadSummary>> getThreads(String postId) => _publicClient.getThreads(postId);

  // ---- escape hatch for future authenticated endpoints ----

  /// Runs [call] with a Dio that transparently attaches a valid access
  /// token (refreshing as needed) and retries once after a forced rotation
  /// when the server answers 401. Throws [PlatformAuthRequiredException]
  /// when no valid session exists.
  Future<T> authed<T>(Future<T> Function(Dio authedDio) call) async {
    try {
      return await call(_authedDio);
    } on DioException catch (e) {
      final error = e.error;
      if (error is PlatformAuthRequiredException) throw error;
      rethrow;
    }
  }

  // ---- token lifecycle (package-internal) ----

  /// Cold start: loads the stored session and rotates it once. Never
  /// throws: an unreadable store reads as signed out.
  Future<void> _initialize() async {
    try {
      final session = await _store.read();
      if (session == null) return;
      await _startupRefresh(session);
    } on Object {
      _setIdentity(null);
    }
  }

  /// Rotates the stored session. Offline-tolerant: any failure other than
  /// the server rejecting the token keeps the session as-is.
  Future<void> _startupRefresh(StoredPlatformSession session) => _mutex.synchronized(() async {
    // Re-read inside the critical section: a login or logout may have
    // replaced the session while this refresh was queued on the mutex.
    final current = await _store.read();
    if (current == null) {
      _setIdentity(null);
      return;
    }
    if (current.refreshToken != session.refreshToken) {
      // Another flow already rotated or replaced the session; keep it.
      _setIdentity(current.identity);
      return;
    }
    try {
      final pair = await _authClient.refresh(refreshToken: current.refreshToken);
      // Validate the rotated pair against the stored identity before
      // persistence: a refresh result with no subject, or with a subject
      // different from the stored user id, must not replace the stored
      // access token while the state still identifies the prior account.
      // Keep the stored session as-is; the server already rotated the
      // refresh token, so a later expiry-triggered refresh will be rejected
      // and force a re-login.
      final subject = decodeJwtSubject(pair.accessToken);
      if (subject == null || subject.isEmpty || subject != current.userId) {
        _setIdentity(current.identity);
        return;
      }
      try {
        await _store.write(current.rotated(pair));
      } on Object {
        // The server already rotated the pair but the successor could not
        // be persisted. The stored session is untouched (single-key atomic
        // write), so the app keeps working on it; the next expiry-triggered
        // refresh may be rejected and force a re-login.
      }
    } on AccountApiException catch (e) {
      if (e.isInvalidToken) {
        // The refresh token is dead (expired, revoked, or reused): sign out.
        // Deliberately no onAuthRequired here: nothing is in flight that a
        // login redirect would recover, and a navigation at cold start would
        // yank the user out of whatever they opened.
        await _clearSessionLocked();
        return;
      }
      // e.g. rate-limited: keep the stored session.
    } on Object {
      // Offline or unreachable: keep the stored session.
    }
    _setIdentity(current.identity);
  });

  /// Returns a usable access token, refreshing (and persisting the rotated
  /// pair) when the stored one is expired or about to expire.
  ///
  /// The whole read-check-refresh-write sequence runs inside the session
  /// mutex: a concurrent caller observes the already-rotated pair on its
  /// re-read and reuses it instead of rotating a second time (a duplicate
  /// refresh would invalidate the freshly stored pair server-side).
  Future<String> _requireValidAccessToken() => _mutex.synchronized(() async {
    final session = await _store.read();
    if (session == null) {
      _setIdentity(null);
      _fireAuthRequired();
      throw const PlatformAuthRequiredException("not signed in");
    }
    if (session.expiresAt.isAfter(DateTime.now().add(_refreshSkew))) {
      return session.accessToken;
    }
    return _refreshLocked(session);
  });

  /// Returns a freshly rotated access token regardless of the stored one's
  /// expiry; used by the 401 retry path, where the attached token was
  /// rejected despite looking valid locally.
  Future<String> _forceRefreshAccessToken() => _mutex.synchronized(() async {
    final session = await _store.read();
    if (session == null) {
      _setIdentity(null);
      _fireAuthRequired();
      throw const PlatformAuthRequiredException("not signed in");
    }
    return _refreshLocked(session);
  });

  /// Rotates [session]'s refresh token and persists the successor pair.
  /// Caller must hold the session mutex. A rejected refresh or a rotated
  /// pair identifying another account clears the doomed session (the server
  /// already rotated its refresh token, so it can never produce a usable
  /// token again) and throws [PlatformAuthRequiredException].
  Future<String> _refreshLocked(StoredPlatformSession session) async {
    final AuthTokenPair pair;
    try {
      pair = await _authClient.refresh(refreshToken: session.refreshToken);
    } on AccountApiException catch (e) {
      if (e.isInvalidToken) {
        await _clearSessionLocked();
        _fireAuthRequired();
        throw const PlatformAuthRequiredException("the session was rejected by the server");
      }
      rethrow;
    }
    final subject = decodeJwtSubject(pair.accessToken);
    if (subject == null || subject.isEmpty || subject != session.userId) {
      await _clearSessionLocked();
      _fireAuthRequired();
      throw const PlatformAuthRequiredException(
        "the refreshed token identifies a different account",
      );
    }
    final rotated = session.rotated(pair);
    await _store.write(rotated);
    return rotated.accessToken;
  }

  Future<void> _acceptTokenPair(String email, AuthTokenPair pair) async {
    // The auth API has no profile endpoint; the user id comes from the JWT
    // subject and the email is the address the user just authenticated with.
    // Reject a pair whose access token carries no usable subject: persisting
    // it would create a signed-in state with an invalid cached identity.
    final userId = decodeJwtSubject(pair.accessToken);
    if (userId == null || userId.isEmpty) {
      await _clearSession();
      throw const AccountApiException(null, "invalid_token", "access token has no usable subject");
    }
    await _mutex.synchronized(() async {
      await _store.write(
        StoredPlatformSession(
          accessToken: pair.accessToken,
          refreshToken: pair.refreshToken,
          expiresAt: DateTime.now().add(Duration(seconds: pair.expiresIn)),
          email: email,
          userId: userId,
        ),
      );
      _authRequiredFired = false;
      _setIdentity(PlatformIdentity(userId: userId, email: email));
    });
  }

  Future<void> _clearSession() => _mutex.synchronized(_clearSessionLocked);

  /// Session clear for callers already holding the session mutex.
  Future<void> _clearSessionLocked() async {
    await _store.clear();
    _setIdentity(null);
  }

  void _fireAuthRequired() {
    if (_authRequiredFired) return;
    _authRequiredFired = true;
    _onAuthRequired?.call();
  }
}

extension on StoredPlatformSession {
  PlatformIdentity get identity => PlatformIdentity(userId: userId, email: email);

  StoredPlatformSession rotated(AuthTokenPair pair) => StoredPlatformSession(
    accessToken: pair.accessToken,
    refreshToken: pair.refreshToken,
    expiresAt: DateTime.now().add(Duration(seconds: pair.expiresIn)),
    email: email,
    userId: userId,
  );
}

/// Dio interceptor behind [PlatformSession.authed]: attaches a valid access
/// token before each request and retries once after a forced rotation when
/// the server answers 401. Queued, so concurrent requests serialize on the
/// token resolution (and share a single rotation via the session mutex).
final class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor(this._session);

  final PlatformSession _session;

  static const String _retriedKey = "efaPlatformAuthRetried";

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final token = await _session._requireValidAccessToken();
      options.headers["Authorization"] = "Bearer $token";
      handler.next(options);
    } on Object catch (error, stackTrace) {
      handler.reject(
        DioException(requestOptions: options, error: error, stackTrace: stackTrace),
        true,
      );
    }
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 || err.requestOptions.extra[_retriedKey] == true) {
      handler.next(err);
      return;
    }
    // The attached token was rejected (e.g. the account's token version
    // moved past it): force one rotation and retry the request once.
    err.requestOptions.extra[_retriedKey] = true;
    try {
      await _session._forceRefreshAccessToken();
      // Re-runs this interceptor's onRequest, which attaches the just-
      // rotated token; the marker above prevents a second 401 loop.
      final response = await _session._authedDio.fetch<dynamic>(err.requestOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    } on Object catch (error, stackTrace) {
      handler.next(
        DioException(requestOptions: err.requestOptions, error: error, stackTrace: stackTrace),
      );
    }
  }
}
