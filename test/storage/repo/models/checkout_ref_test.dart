import "dart:convert";

import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("CheckoutRef", () {
    test("JSON round-trip", () {
      final ref = CheckoutRef(
        checkoutId: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        serverId: "serenity",
      );
      final restored = CheckoutRef.fromJson(
        jsonDecode(jsonEncode(ref.toJson())) as Map<String, dynamic>,
      );
      expect(restored, ref);
    });

    test("JSON round-trip with empty checkoutId (sentinel)", () {
      const ref = CheckoutRef(checkoutId: "", serverId: "serenity");
      final restored = CheckoutRef.fromJson(
        jsonDecode(jsonEncode(ref.toJson())) as Map<String, dynamic>,
      );
      expect(restored, ref);
      expect(restored.checkoutId, "");
      expect(restored.checkoutId.isEmpty, isTrue);
    });

    test("fromJson with known shape", () {
      final json =
          jsonDecode(
                '{'
                '  "checkoutId": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",'
                '  "serverId": "serenity"'
                '}',
              )
              as Map<String, dynamic>;
      final ref = CheckoutRef.fromJson(json);
      expect(ref.checkoutId, "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef");
      expect(ref.serverId, "serenity");
    });
  });
}
