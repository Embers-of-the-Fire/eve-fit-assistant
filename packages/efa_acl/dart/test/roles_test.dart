import "package:efa_acl/efa_acl.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("roles", () {
    test("grants fresh accounts the default user role", () {
      expect(aclDefaultRoles, [AclRole.user]);
      expect(tokensForRoles(aclDefaultRoles.map((role) => role.name)), {
        "post:create",
        "post:delete:own",
      });
    });

    test("role bundles expose their tokens as typed values", () {
      expect(AclRole.user.tokens, [const PostCreate(), const PostDelete(PostDeleteQualifier.own)]);
      expect(AclRole.admin.tokens, [
        const PostCreate(),
        const PostDelete(PostDeleteQualifier.all),
        const AdminManageRoles(),
      ]);
    });

    test("resolves roles to the union of their tokens", () {
      expect(tokensForRoles(["moderator"]), {"post:create", "post:delete:own", "post:delete:all"});
      expect(tokensForRoles(["user", "admin"]), {
        "post:create",
        "post:delete:own",
        "post:delete:all",
        "admin:manage_roles",
      });
    });

    test("ignores unknown role names", () {
      expect(tokensForRoles(["superuser"]), isEmpty);
      expect(AclRole.tryByName("superuser"), isNull);
      expect(AclRole.tryByName("admin"), AclRole.admin);
    });

    test("builds a queryable token set", () {
      final acl = aclForRoles(["admin"]);
      expect(acl.canPostCreate(), isTrue);
      expect(acl.canPostDelete(), {PostDeleteQualifier.all});
      expect(acl.canAdminManageRoles(), isTrue);
      expect(aclForRoles(["user"]).canAdminManageRoles(), isFalse);
    });
  });
}
