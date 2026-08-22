import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/account/account_api.dart";
import "package:eve_fit_assistant/features/account/token_store.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "account_controller.g.dart";

/// Refresh the access token when it expires within this window.
const Duration _refreshSkew = Duration(minutes: 1);

/// Simple Future-based mutex for serializing session mutations (same pattern
/// as the checkout registry).
class _Mutex {
  Future<void> _last = Future.value();

  Future<T> synchronized<T>(Future<T> Function() fn) {
    final prev = _last;
    final next = prev.then((_) => fn());
    _last = next.then((_) => null, onError: (_) => null);
    return next;
  }
}

/// Reactive account session state.
sealed class AccountState {
  const AccountState();
}

final class AccountSignedOut extends AccountState {
  const AccountSignedOut();
}

final class AccountSignedIn extends AccountState {
  const AccountSignedIn({required this.email, required this.userId});

  final String email;
  final String userId;
}

/// Injectable seam for the auth API client, so tests can substitute a fake
/// transport.
typedef AccountApiClientFactory =
    AccountApiClient Function({required String origin, String? cfAccessToken});

@riverpodSingleton
AccountApiClientFactory accountApiClientFactory(Ref ref) =>
    ({required origin, cfAccessToken}) =>
        AccountApiClient(origin: origin, cfAccessToken: cfAccessToken);

/// Orchestrates the platform account flows (signup, verification, login,
/// refresh, logout, deregistration) against the auth API and keeps the local
/// session state: tokens in secure storage, the display profile (email,
/// user id) cached in [AppSetting.account].
///
/// The session is rotated once per cold start (the provider is eagerly
/// instantiated from `initWithRef`), which keeps the 30-day refresh token
/// alive for active users and drops stale sessions early.
///
/// All flows that read-refresh-write or replace the session run inside
/// [_sessionMutex] and re-read the stored session inside the critical
/// section: refresh tokens rotate server-side on every refresh, so two
/// overlapping refreshes would invalidate each other's stored pair, and a
/// stale read could resurrect a cleared session.
@riverpodSingleton
class AccountController extends _$AccountController {
  final _Mutex _sessionMutex = _Mutex();

  @override
  Future<AccountState> build() async {
    final session = await ref.watch(accountTokenStoreProvider).readSession();
    if (session == null) {
      return const AccountSignedOut();
    }
    return _startupRefresh(session);
  }

  /// Rotates the stored session. Offline-tolerant: any failure other than
  /// the server rejecting the token keeps the session as-is.
  Future<AccountState> _startupRefresh(AccountSession session) =>
      _sessionMutex.synchronized(() async {
        // Re-read inside the critical section: a login or logout may have
        // replaced the session while this refresh was queued on the mutex.
        final store = ref.read(accountTokenStoreProvider);
        final current = await store.readSession();
        final account = ref.read(appSettingServiceProvider).account;
        final email = account.email;
        final userId = account.userId;
        if (current == null || email == null || userId == null) {
          return const AccountSignedOut();
        }
        if (current.refreshToken != session.refreshToken) {
          // Another flow already rotated or replaced the session; keep it.
          return AccountSignedIn(email: email, userId: userId);
        }
        try {
          final pair = await (await _client()).refresh(refreshToken: current.refreshToken);
          try {
            await store.writeSession(_sessionFromPair(pair));
          } on Object catch (error, stackTrace) {
            // The server already rotated the pair but the successor could not
            // be persisted. The stored session is untouched (single-key atomic
            // write), so the app keeps working on it; the next expiry-triggered
            // refresh may be rejected and force a re-login. Surface the loss in
            // the log instead of treating it as a generic network failure.
            warning(
              "Account startup refresh: rotated session could not be persisted: $error",
              stackTrace: stackTrace,
            );
          }
        } on AccountApiException catch (e) {
          if (e.isInvalidToken) {
            // The refresh token is dead (expired, revoked, or reused): sign out.
            await _clearStoredSession();
            return const AccountSignedOut();
          }
          // e.g. rate-limited: keep the stored session.
        } on Object {
          // Offline or unreachable: keep the stored session.
        }
        return AccountSignedIn(email: email, userId: userId);
      });

  Future<AccountApiClient> _client() async {
    final setting = ref.read(appSettingServiceProvider);
    final custom = setting.account.customOrigin.trim();
    // The custom origin is a developer-only override: use it only while
    // developer mode is on, and never clear the stored value.
    final origin = setting.developerMode && custom.isNotEmpty ? custom : accountApiProductionOrigin;
    final cfAccessToken = await ref.read(accountTokenStoreProvider).readCfAccessToken();
    return ref.read(accountApiClientFactoryProvider)(
      origin: origin,
      cfAccessToken: cfAccessToken.isEmpty ? null : cfAccessToken,
    );
  }

  /// The locale passed to OTP-sending endpoints for bilingual email
  /// templates (`en`/`zh`).
  String get _emailLocale => ref.read(localeProvider).name;

  /// `POST /login`. Throws [AccountApiException] on failure; the UI maps
  /// `email_unverified` to the verification flow.
  Future<void> login(String email, String password) async {
    final pair = await (await _client()).login(email: email, password: password);
    await _acceptTokenPair(email, pair);
  }

  /// `POST /signup`: creates the pending account and sends the verification
  /// code. Also used to resend the code for an already-pending address.
  Future<void> signup(String email, String password) async =>
      (await _client()).signup(email: email, password: password, locale: _emailLocale);

  /// `POST /signup/resend`: resends the verification code for a pending
  /// account without a password (the verification step may be reached from
  /// the login redirect, where the password was never collected).
  Future<void> resendSignupCode(String email) async =>
      (await _client()).signupResend(email: email, locale: _emailLocale);

  /// `POST /verify-email`: activates the pending account and signs in.
  Future<void> verifyEmail(String email, String code) async {
    final pair = await (await _client()).verifyEmail(email: email, code: code);
    await _acceptTokenPair(email, pair);
  }

  /// `POST /reset-password`: sends a reset code when the address belongs to
  /// an active account (the response never reveals which).
  Future<void> requestPasswordReset(String email) async =>
      (await _client()).resetPassword(email: email, locale: _emailLocale);

  /// `POST /reset-password/confirm`: sets the new password and signs in with
  /// the freshly issued pair (all previous sessions are revoked server-side).
  Future<void> confirmPasswordReset(String email, String code, String newPassword) async {
    final pair = await (await _client()).resetPasswordConfirm(
      email: email,
      code: code,
      newPassword: newPassword,
    );
    await _acceptTokenPair(email, pair);
  }

  /// `POST /logout` (best-effort), then clears the local session.
  Future<void> logout() => _sessionMutex.synchronized(() async {
    final session = await ref.read(accountTokenStoreProvider).readSession();
    if (session != null) {
      try {
        await (await _client()).logout(refreshToken: session.refreshToken);
      } on Object {
        // Logout stays local: the refresh token dies with its 30-day TTL.
      }
    }
    await _clearSessionLocked();
  });

  /// Drops the local session without any server call (endpoint switches).
  Future<void> signOutLocal() => _clearSession();

  /// `POST /deregister` with a fresh access token plus password
  /// re-authentication, then clears the local session.
  Future<void> deregister(String password) async {
    final accessToken = await _requireValidAccessToken();
    await (await _client()).deregister(accessToken: accessToken, password: password);
    await _clearSession();
  }

  /// Returns a usable access token, refreshing (and persisting the rotated
  /// pair) when the stored one is expired or about to expire.
  ///
  /// The whole read-check-refresh-write sequence runs inside the session
  /// mutex: a concurrent caller observes the already-rotated pair on its
  /// re-read and reuses it instead of rotating a second time (a duplicate
  /// refresh would invalidate the freshly stored pair server-side).
  Future<String> _requireValidAccessToken() => _sessionMutex.synchronized(() async {
    final store = ref.read(accountTokenStoreProvider);
    final session = await store.readSession();
    if (session == null) {
      throw const AccountApiException(401, "invalid_token", "not signed in");
    }
    if (session.accessTokenExpiresAt.isAfter(DateTime.now().add(_refreshSkew))) {
      return session.accessToken;
    }
    try {
      final pair = await (await _client()).refresh(refreshToken: session.refreshToken);
      final rotated = _sessionFromPair(pair);
      await store.writeSession(rotated);
      return rotated.accessToken;
    } on AccountApiException catch (e) {
      if (e.isInvalidToken) await _clearSessionLocked();
      rethrow;
    }
  });

  AccountSession _sessionFromPair(AuthTokenPair pair) => AccountSession(
    accessToken: pair.accessToken,
    refreshToken: pair.refreshToken,
    accessTokenExpiresAt: DateTime.now().add(Duration(seconds: pair.expiresIn)),
  );

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
    await _sessionMutex.synchronized(() async {
      await ref.read(accountTokenStoreProvider).writeSession(_sessionFromPair(pair));
      ref
          .read(appSettingServiceProvider.notifier)
          .update(
            (s) => s.copyWith(
              account: s.account.copyWith(email: email, userId: userId),
            ),
          );
      state = AsyncData(AccountSignedIn(email: email, userId: userId));
    });
  }

  Future<void> _clearSession() => _sessionMutex.synchronized(_clearSessionLocked);

  /// Session clear for callers already holding the session mutex.
  Future<void> _clearSessionLocked() async {
    await _clearStoredSession();
    state = const AsyncData(AccountSignedOut());
  }

  /// Storage-only session clear, safe to call from `build` (no state set).
  Future<void> _clearStoredSession() async {
    await ref.read(accountTokenStoreProvider).clearSession();
    ref
        .read(appSettingServiceProvider.notifier)
        .update((s) => s.copyWith(account: s.account.copyWith(email: null, userId: null)));
  }
}
