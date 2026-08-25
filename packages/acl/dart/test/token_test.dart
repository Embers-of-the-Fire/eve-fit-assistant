import "package:acl/acl.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("parseToken", () {
    test("parses an unqualified token", () {
      final parts = parseToken("post:create");
      expect(parts.domain, "post");
      expect(parts.action, "create");
      expect(parts.qualifier, isNull);
    });

    test("parses a qualified token", () {
      final parts = parseToken("post:delete:own");
      expect(parts.domain, "post");
      expect(parts.action, "delete");
      expect(parts.qualifier, "own");
    });

    test("accepts underscores and digits in segments", () {
      final parts = parseToken("blog_post:edit_v2:v2_draft");
      expect(parts.domain, "blog_post");
      expect(parts.action, "edit_v2");
      expect(parts.qualifier, "v2_draft");
    });

    for (final token in [
      "",
      "post",
      "post:delete:own:extra",
      "post::own",
      ":create",
      "Post:create",
      "post:Create",
      "post:create:Own",
      "post:create-own",
      "post:delete:",
    ]) {
      test("rejects malformed token '$token'", () {
        expect(
          () => parseToken(token),
          throwsA(
            isA<AclTokenFormatException>().having((exception) => exception.token, "token", token),
          ),
        );
      });
    }
  });

  group("TokenParts.encode", () {
    test("round-trips unqualified tokens", () {
      expect(const TokenParts(domain: "post", action: "create").encode(), "post:create");
    });

    test("round-trips qualified tokens", () {
      expect(parseToken("post:delete:own").encode(), "post:delete:own");
    });
  });
}
