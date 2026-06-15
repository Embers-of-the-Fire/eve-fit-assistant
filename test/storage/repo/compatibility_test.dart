import "package:eve_fit_assistant/storage/repo/compatibility.dart";
import "package:eve_fit_assistant/storage/repo/models/compatibility.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  final service = const CompatibilityService();

  group("CompatibilityService.check", () {
    test("returns incompatible when serverId differs", () {
      final result = service.check(
        CompatibilityRequest(
          serverId: "serenity",
          checkoutId: "hash_abc",
          targetServerId: "tranquility",
          targetCheckoutId: "hash_abc",
        ),
      );
      expect(result.result, CompatibilityResult.incompatible);
    });

    test("returns compatible when checkoutId exact matches (same server)", () {
      final result = service.check(
        CompatibilityRequest(
          serverId: "serenity",
          checkoutId: "hash_abc",
          targetServerId: "serenity",
          targetCheckoutId: "hash_abc",
        ),
      );
      expect(result.result, CompatibilityResult.compatible);
    });

    test("returns outdated when same serverId but different checkoutId", () {
      final result = service.check(
        CompatibilityRequest(
          serverId: "serenity",
          checkoutId: "hash_abc",
          targetServerId: "serenity",
          targetCheckoutId: "hash_def",
        ),
      );
      expect(result.result, CompatibilityResult.outdated);
    });

    test("returns incompatible when both serverId and checkoutId differ", () {
      final result = service.check(
        CompatibilityRequest(
          serverId: "serenity",
          checkoutId: "hash_abc",
          targetServerId: "tranquility",
          targetCheckoutId: "hash_def",
        ),
      );
      expect(result.result, CompatibilityResult.incompatible);
    });

    test("returns compatible when both checkoutId are empty (sentinel match)", () {
      final result = service.check(
        CompatibilityRequest(
          serverId: "serenity",
          checkoutId: "",
          targetServerId: "serenity",
          targetCheckoutId: "",
        ),
      );
      expect(result.result, CompatibilityResult.compatible);
    });

    test("returns outdated when checkoutId differs and targetCheckoutId is empty"
        " sentinel (same server)", () {
      final result = service.check(
        CompatibilityRequest(
          serverId: "serenity",
          checkoutId: "hash_abc",
          targetServerId: "serenity",
          targetCheckoutId: "",
        ),
      );
      expect(result.result, CompatibilityResult.outdated);
    });
  });
}
