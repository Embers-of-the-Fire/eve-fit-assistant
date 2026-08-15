import "package:eve_fit_assistant/storage/repo/checkout_db.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("checkout database OPFS naming helpers", () {
    test("checkoutDbNameForHash embeds the content hash under the prefix", () {
      expect(checkoutDbNameForHash("localization", "deadbeef"), "localization_deadbeef");
      expect(checkoutDbNameForHash("agent_resource", "deadbeef"), "agent_resource_deadbeef");
    });

    test("checkoutDbFilePath nests the database file under the OPFS root", () {
      expect(
        checkoutDbFilePath("agent_resource_deadbeef"),
        "$kCheckoutDbOpfsRoot/agent_resource_deadbeef/database",
      );
    });

    test("isStaleCheckoutDbDir is prefix-scoped and keeps the current name", () {
      expect(
        isStaleCheckoutDbDir(
          "agent_resource",
          "agent_resource_old",
          keepName: "agent_resource_new",
        ),
        isTrue,
      );
      expect(
        isStaleCheckoutDbDir(
          "agent_resource",
          "agent_resource_new",
          keepName: "agent_resource_new",
        ),
        isFalse,
      );
      expect(
        isStaleCheckoutDbDir("agent_resource", "localization_old", keepName: "agent_resource_new"),
        isFalse,
      );
    });
  });
}
