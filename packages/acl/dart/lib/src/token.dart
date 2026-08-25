final _segmentPattern = RegExp(r"^[a-z][a-z0-9_]*$");

/// Grammar-level parts of an ACL token: `{domain}:{action}[:{qualifier}]`.
final class TokenParts {
  const TokenParts({required this.domain, required this.action, this.qualifier});

  /// The permission domain, e.g. `post`.
  final String domain;

  /// The action within [domain], e.g. `create`.
  final String action;

  /// The optional qualifier narrowing [action], e.g. `own`.
  final String? qualifier;

  /// Encodes these parts back into their string form.
  String encode() => qualifier == null ? "$domain:$action" : "$domain:$action:$qualifier";
}

/// Exception thrown when a string does not satisfy the ACL token grammar.
final class AclTokenFormatException implements Exception {
  const AclTokenFormatException(this.token, this.reason);

  /// The offending token.
  final String token;

  /// Why the token is malformed.
  final String reason;

  @override
  String toString() => 'Invalid ACL token "$token": $reason';
}

/// Parses [token] into its grammar-level parts.
///
/// This validates the token grammar only; whether the domain, action, or
/// qualifier actually exist is a schema-level concern (see the generated
/// `parseAclToken`). Throws [AclTokenFormatException] on malformed input.
TokenParts parseToken(String token) {
  final segments = token.split(":");
  if (segments.length < 2 || segments.length > 3) {
    throw AclTokenFormatException(token, "expected 2 or 3 segments, found ${segments.length}");
  }
  for (final segment in segments) {
    if (!_segmentPattern.hasMatch(segment)) {
      throw AclTokenFormatException(token, 'invalid segment "$segment"');
    }
  }
  return TokenParts(
    domain: segments[0],
    action: segments[1],
    qualifier: segments.length == 3 ? segments[2] : null,
  );
}
