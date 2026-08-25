/// A set of ACL tokens with membership and action-level queries.
///
/// Matching is exact: a token only covers its own qualifier; broader
/// qualifiers never imply narrower ones (e.g. `post:delete:all` does not
/// satisfy a query for `own`).
///
/// Construction is O(n) and indexes tokens by action key, so both [has] and
/// [can] are O(1) hash lookups (plus O(k) for the k matched qualifiers).
/// Tokens are expected to satisfy the grammar; malformed tokens are stored
/// but not validated.
final class Acl {
  /// Creates a token set from encoded token strings.
  Acl(Iterable<String> tokens)
    : _tokens = Set.unmodifiable(tokens),
      _actions = _indexActions(tokens);

  final Set<String> _tokens;
  final Map<String, Set<String>> _actions;

  static Map<String, Set<String>> _indexActions(Iterable<String> tokens) {
    final actions = <String, Set<String>>{};
    for (final token in tokens) {
      final firstColon = token.indexOf(":");
      final secondColon = firstColon == -1 ? -1 : token.indexOf(":", firstColon + 1);
      if (secondColon == -1) {
        // Unqualified token: the token itself is the action key and is
        // answered by the exact-membership check in [can].
        continue;
      }
      actions
          .putIfAbsent(token.substring(0, secondColon), () => {})
          .add(token.substring(secondColon + 1));
    }
    return Map.unmodifiable(actions);
  }

  /// The raw token strings in this set.
  Set<String> get tokens => _tokens;

  /// Whether [token] is present exactly, qualifier included.
  bool has(String token) => _tokens.contains(token);

  /// Queries an action key (`"{domain}:{action}"`).
  ///
  /// Returns `true`/`false` for actions declared without qualifiers, and the
  /// set of matched qualifiers (or `false` when the action is absent) for
  /// qualified actions. Schema-generated typed queries (e.g. `canPostDelete`)
  /// unwrap this result.
  Object can(String action) {
    if (_tokens.contains(action)) {
      return true;
    }
    final matched = _actions[action];
    return matched == null ? false : Set.unmodifiable(matched);
  }
}
