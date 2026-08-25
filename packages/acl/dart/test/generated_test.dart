import "package:acl/acl.dart";
import "package:flutter_test/flutter_test.dart";

import "fixtures/generated/acl_test.generated.dart";

void main() {
  group("generated bindings (example schema)", () {
    test("parseAclToken parses defined tokens", () {
      expect(parseAclToken("post:create"), isA<PostCreate>());
      expect(parseAclToken("post:delete:own"), isA<PostDelete>());
      expect(parseAclToken("comment:create"), isA<CommentCreate>());
      final token = parseAclToken("post:delete:all");
      expect(token, isA<PostDelete>());
      expect((token! as PostDelete).qualifier, PostDeleteQualifier.all);
    });

    test("parseAclToken rejects tokens outside the schema", () {
      expect(parseAclToken("post:delete:other"), isNull);
      expect(parseAclToken("post:delete"), isNull);
      expect(parseAclToken("unknown:create"), isNull);
    });

    test("encode round-trips", () {
      expect(const PostCreate().encode(), "post:create");
      expect(const PostDelete(PostDeleteQualifier.own).encode(), "post:delete:own");
      expect(const CommentDelete(CommentDeleteQualifier.all).encode(), "comment:delete:all");
    });

    test("typed queries unwrap can()", () {
      final acl = Acl(["post:create", "post:delete:all"]);
      expect(acl.canPostCreate(), isTrue);
      expect(acl.canPostDelete(), {PostDeleteQualifier.all});
      expect(acl.canCommentDelete(), isNull);
      expect(Acl([]).canPostCreate(), isFalse);
    });

    test("hasToken checks exact membership", () {
      final acl = Acl(["post:delete:all"]);
      expect(acl.hasToken(const PostDelete(PostDeleteQualifier.all)), isTrue);
      expect(acl.hasToken(const PostDelete(PostDeleteQualifier.own)), isFalse);
      expect(acl.hasToken(const PostCreate()), isFalse);
    });
  });

  group("generated role bindings (example schema)", () {
    test("lists roles in declaration order with the default marker", () {
      expect(aclRoles, [AclRole.user, AclRole.moderator]);
      expect(aclDefaultRoles, [AclRole.user]);
      expect(AclRole.tryByName("ghost"), isNull);
      expect(AclRole.tryByName("user"), AclRole.user);
    });

    test("role bundles expose their tokens", () {
      expect(AclRole.user.tokens.map((token) => token.encode()), [
        "post:create",
        "post:delete:own",
        "comment:create",
        "comment:delete:own",
      ]);
    });

    test("resolves roles to the union of their tokens, ignoring unknown names", () {
      expect(tokensForRoles(["user"]), {
        "post:create",
        "post:delete:own",
        "comment:create",
        "comment:delete:own",
      });
      expect(tokensForRoles(["ghost"]), isEmpty);
      expect(tokensForRoles(["user", "moderator"]), {
        "post:create",
        "post:delete:own",
        "post:delete:all",
        "comment:create",
        "comment:delete:own",
        "comment:delete:all",
      });
    });

    test("builds a queryable token set from roles", () {
      final acl = aclForRoles(aclDefaultRoles.map((role) => role.name));
      expect(acl.canPostCreate(), isTrue);
      expect(acl.canCommentDelete(), {CommentDeleteQualifier.own});
      expect(aclForRoles(["moderator"]).canPostDelete(), {PostDeleteQualifier.all});
    });
  });
}
