import "dart:convert";

import "package:eve_fit_assistant/storage/repo/models/diff.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("DiffAdd", () {
    test("JSON round-trip", () {
      final add = DiffAdd(path: "c", pathHash: "hash-c", hash: "123", size: 100);
      final restored = DiffAdd.fromJson(
        jsonDecode(jsonEncode(add.toJson())) as Map<String, dynamic>,
      );
      expect(restored, add);
    });
  });

  group("DiffDelete", () {
    test("JSON round-trip (no hash)", () {
      final del = DiffDelete(path: "c", pathHash: "hash-c", size: 100);
      final json = del.toJson();
      expect(json["hash"], isNull);
      final restored = DiffDelete.fromJson(
        jsonDecode(jsonEncode(del.toJson())) as Map<String, dynamic>,
      );
      expect(restored, del);
    });

    test("JSON round-trip (with hash from inverted diff)", () {
      final del = DiffDelete(path: "c", pathHash: "hash-c", size: 100, hash: "abc123");
      final json = del.toJson();
      expect(json["hash"], "abc123");
      final restored = DiffDelete.fromJson(
        jsonDecode(jsonEncode(del.toJson())) as Map<String, dynamic>,
      );
      expect(restored, del);
      expect(restored.hash, "abc123");
    });
  });

  group("DiffModify", () {
    test("JSON round-trip", () {
      final modify = DiffModify(path: "b", pathHash: "hash-b", hash: "efg", size: 100);
      final restored = DiffModify.fromJson(
        jsonDecode(jsonEncode(modify.toJson())) as Map<String, dynamic>,
      );
      expect(restored, modify);
    });
  });

  group("ReflogEntry", () {
    test("JSON round-trip", () {
      final entry = ReflogEntry(
        id: "diff-uuid-001",
        timestamp: "2024-01-15T10:30:00Z",
        from: "hash-a",
        to: "hash-b",
      );
      final restored = ReflogEntry.fromJson(
        jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>,
      );
      expect(restored, entry);
    });
  });

  group("Diff", () {
    test("JSON round-trip: add-only diff", () {
      // Spec example: A={a: abc, b: cde} → B={a: abc, b: efg, c: 123}
      final diff = Diff(
        from: "hash-a",
        to: "hash-b",
        fromCreatedAt: "2024-01-15T00:00:00Z",
        toCreatedAt: "2024-01-16T00:00:00Z",
        adds: IList([DiffAdd(path: "c", pathHash: "hash-c", hash: "123", size: 0)]),
        modifies: IList([DiffModify(path: "b", pathHash: "hash-b", hash: "efg", size: 0)]),
      );
      final restored = Diff.fromJson(jsonDecode(jsonEncode(diff.toJson())) as Map<String, dynamic>);
      expect(restored, diff);
      expect(restored.adds.length, 1);
      expect(restored.deletes.length, 0);
      expect(restored.modifies.length, 1);
    });

    test("JSON round-trip: modify-only diff with inverted diff", () {
      // Inverted diff example: B={a: abc, b: efg, c: 123} → A={a: abc, b: cde}
      final diff = Diff(
        from: "hash-b",
        to: "hash-a",
        fromCreatedAt: "2024-01-16T00:00:00Z",
        toCreatedAt: "2024-01-15T00:00:00Z",
        deletes: IList([DiffDelete(path: "c", pathHash: "hash-c", size: 0)]),
        modifies: IList([DiffModify(path: "b", pathHash: "hash-b", hash: "cde", size: 0)]),
      );
      final restored = Diff.fromJson(jsonDecode(jsonEncode(diff.toJson())) as Map<String, dynamic>);
      expect(restored, diff);
      expect(restored.adds.length, 0);
      expect(restored.deletes.length, 1);
      expect(restored.modifies.length, 1);
    });

    test("JSON round-trip: add+modify diff (C to A revert)", () {
      // C={b: cde, c: 123} → A={a: abc, b: cde}
      final diff = Diff(
        from: "hash-c",
        to: "hash-a",
        fromCreatedAt: "2024-01-17T00:00:00Z",
        toCreatedAt: "2024-01-15T00:00:00Z",
        adds: IList([DiffAdd(path: "a", pathHash: "hash-a", hash: "abc", size: 0)]),
        deletes: IList([DiffDelete(path: "c", pathHash: "hash-c", size: 0)]),
        modifies: IList([DiffModify(path: "b", pathHash: "hash-b", hash: "cde", size: 0)]),
      );
      final restored = Diff.fromJson(jsonDecode(jsonEncode(diff.toJson())) as Map<String, dynamic>);
      expect(restored, diff);
      expect(restored.adds.length, 1);
      expect(restored.deletes.length, 1);
      expect(restored.modifies.length, 1);
    });

    test("JSON round-trip with empty collections", () {
      final diff = Diff(
        from: "hash-a",
        to: "hash-b",
        fromCreatedAt: "2024-01-15T00:00:00Z",
        toCreatedAt: "2024-01-16T00:00:00Z",
      );
      final restored = Diff.fromJson(jsonDecode(jsonEncode(diff.toJson())) as Map<String, dynamic>);
      expect(restored.adds.isEmpty, isTrue);
      expect(restored.deletes.isEmpty, isTrue);
      expect(restored.modifies.isEmpty, isTrue);
      expect(restored, diff);
    });

    test("fromJson with known shape", () {
      final json =
          jsonDecode(
                '{'
                '  "from": "hash-a",'
                '  "to": "hash-b",'
                '  "fromCreatedAt": "2024-01-15T00:00:00Z",'
                '  "toCreatedAt": "2024-01-16T00:00:00Z",'
                '  "adds": [{"path": "c", "pathHash": "hash-c", "hash": "123", "size": 100}],'
                '  "deletes": [{"path": "d", "pathHash": "hash-d", "size": 200}],'
                '  "modifies": [{"path": "b", "pathHash": "hash-b", "hash": "efg", "size": 300}]'
                '}',
              )
              as Map<String, dynamic>;
      final diff = Diff.fromJson(json);
      expect(diff.from, "hash-a");
      expect(diff.to, "hash-b");
      expect(diff.fromCreatedAt, "2024-01-15T00:00:00Z");
      expect(diff.toCreatedAt, "2024-01-16T00:00:00Z");
      expect(diff.adds.length, 1);
      expect(diff.adds.first.path, "c");
      expect(diff.adds.first.hash, "123");
      expect(diff.deletes.length, 1);
      expect(diff.deletes.first.path, "d");
      expect(diff.modifies.length, 1);
      expect(diff.modifies.first.path, "b");
      expect(diff.modifies.first.hash, "efg");
    });
  });
}
