/// A locally held platform session: the token pair from the auth API plus
/// the access token's expiry instant and the cached account identity
/// (refresh tokens are rotated server-side on every refresh, so the stored
/// pair is always the latest).
final class StoredPlatformSession {
  const StoredPlatformSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.email,
    required this.userId,
  });

  final String accessToken;
  final String refreshToken;

  /// Instant the access token expires at, derived from the pair's
  /// `expiresIn` at issuance.
  final DateTime expiresAt;

  /// The address the user authenticated with; the auth API has no profile
  /// endpoint, so it is cached here.
  final String email;

  /// The account's user id (the access token's JWT subject).
  final String userId;
}

/// Persistence boundary of the platform session: the app implements this
/// over platform secure storage. Implementations must write a session
/// atomically (a single-key document), so a failure mid-rotation can never
/// leave a partially updated (mixed-generation) credential set behind.
abstract class PlatformSessionStore {
  /// The stored session, or null when signed out (or the blob is corrupt).
  Future<StoredPlatformSession?> read();

  /// Persists [session] as one atomic write.
  Future<void> write(StoredPlatformSession session);

  /// Drops the stored session completely; must not fail silently (a
  /// surviving record would resurrect the dead session on the next read).
  Future<void> clear();
}
