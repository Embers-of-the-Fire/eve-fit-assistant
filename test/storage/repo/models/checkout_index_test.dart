import "dart:convert";

import "package:eve_fit_assistant/storage/repo/models/checkout_index.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("CheckoutIndex", () {
    test("JSON round-trip with entries", () {
      final index = CheckoutIndex(
        schemaVersion: 1,
        entries: IMap({
          "hash-a": const CheckoutEntry(state: CheckoutState.installed),
          "hash-b": const CheckoutEntry(state: CheckoutState.historical),
          "hash-c": const CheckoutEntry(state: CheckoutState.known),
        }),
      );
      final restored = CheckoutIndex.fromJson(
        jsonDecode(jsonEncode(index.toJson())) as Map<String, dynamic>,
      );
      expect(restored, index);
    });

    test("JSON round-trip with empty entries", () {
      final index = CheckoutIndex(schemaVersion: 1);
      final restored = CheckoutIndex.fromJson(
        jsonDecode(jsonEncode(index.toJson())) as Map<String, dynamic>,
      );
      expect(restored.entries.isEmpty, isTrue);
      expect(restored, index);
    });

    test("fromJson with known shape", () {
      final json =
          jsonDecode(
                '{'
                '  "schemaVersion": 1,'
                '  "entries": {'
                '    "hash-a": {"state": "installed"},'
                '    "hash-b": {"state": "historical"},'
                '    "hash-c": {"state": "known"}'
                '  }'
                '}',
              )
              as Map<String, dynamic>;
      final index = CheckoutIndex.fromJson(json);
      expect(index.entries["hash-a"]!.state, CheckoutState.installed);
      expect(index.entries["hash-b"]!.state, CheckoutState.historical);
      expect(index.entries["hash-c"]!.state, CheckoutState.known);
    });
  });

  group("CheckoutEntry", () {
    test("all three states serialize correctly", () {
      for (final state in CheckoutState.values) {
        final entry = CheckoutEntry(state: state);
        final json = entry.toJson();
        expect(json["state"], state.name);
        final restored = CheckoutEntry.fromJson(json);
        expect(restored.state, state);
      }
    });

    test("unknown state string throws ArgumentError", () {
      expect(() => CheckoutEntry.fromJson({"state": "nonexistent"}), throwsA(isA<ArgumentError>()));
    });
  });

  group("CheckoutState", () {
    test("has three variants", () {
      expect(CheckoutState.values, hasLength(3));
      expect(
        CheckoutState.values,
        containsAll([CheckoutState.installed, CheckoutState.historical, CheckoutState.known]),
      );
    });
  });
}
