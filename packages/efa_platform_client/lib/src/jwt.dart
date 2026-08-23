import "dart:convert";

/// Decodes the `sub` (user id) claim of an access-token JWT without
/// verifying the signature (display metadata only; the server verifies).
String? decodeJwtSubject(String token) {
  final parts = token.split(".");
  if (parts.length != 3) return null;
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final json = jsonDecode(payload);
    if (json is Map<String, dynamic>) return json["sub"] as String?;
  } on Object {
    // Malformed token; treated as undecodable.
  }
  return null;
}
