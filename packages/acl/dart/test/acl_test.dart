import "package:acl/acl.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("Acl", () {
    test("reports exact token membership", () {
      final acl = Acl(["post:create", "post:delete:all"]);
      expect(acl.has("post:create"), isTrue);
      expect(acl.has("post:delete:all"), isTrue);
      expect(acl.has("post:delete:own"), isFalse);
      expect(acl.has("post:delete"), isFalse);
      expect(acl.has("comment:create"), isFalse);
    });

    test("exposes the raw token set", () {
      expect(Acl(["post:create"]).tokens, {"post:create"});
    });

    test("returns true for a granted unqualified action", () {
      expect(Acl(["post:create"]).can("post:create"), true);
    });

    test("returns false for a missing unqualified action", () {
      expect(Acl([]).can("post:create"), false);
    });

    test("returns matched qualifiers for a granted qualified action", () {
      expect(Acl(["post:delete:own", "post:delete:all"]).can("post:delete"), {"own", "all"});
    });

    test("never implies narrower qualifiers from broader ones", () {
      expect(Acl(["post:delete:all"]).can("post:delete"), {"all"});
    });

    test("returns false for a missing qualified action", () {
      expect(Acl(["post:create"]).can("post:delete"), false);
    });

    test("does not confuse similarly prefixed actions", () {
      expect(Acl(["post:create_all:own"]).can("post:create"), false);
    });
  });
}
