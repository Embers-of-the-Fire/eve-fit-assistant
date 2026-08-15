import "package:efa_proto/resource_index.pb.dart";
import "package:eve_fit_assistant/storage/repo/diff.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_test/flutter_test.dart";

ResourceIndex _makeIndex(Map<String, (String, int)> entries) {
  final ri = ResourceIndex()..schemaVersion = 1;
  for (final entry in entries.entries) {
    ri.entries.add(
      ResourceIndex_Entry()
        ..resourceId = entry.key
        ..contentHash = entry.value.$1
        ..size = Int64(entry.value.$2),
    );
  }
  return ri;
}

void main() {
  group("DiffEngine", () {
    late DiffEngine engine;

    setUp(() {
      engine = const DiffEngine();
    });

    test("identical indexes produce empty diff", () {
      final index = _makeIndex({"identA": ("hashA", 100), "identB": ("hashB", 200)});
      final diff = engine.computeDiff(index, index, fromSnapshotHash: "from", toSnapshotHash: "to");
      expect(diff.adds, isEmpty);
      expect(diff.deletes, isEmpty);
      expect(diff.modifies, isEmpty);
    });

    test("new entry produces add", () {
      final from = _makeIndex({});
      final to = _makeIndex({"identA": ("hashA", 100)});
      final diff = engine.computeDiff(from, to, fromSnapshotHash: "from", toSnapshotHash: "to");
      expect(diff.adds.length, 1);
      expect(diff.adds.first.resourceId, "identA");
      expect(diff.deletes, isEmpty);
      expect(diff.modifies, isEmpty);
    });

    test("removed entry produces delete", () {
      final from = _makeIndex({"identA": ("hashA", 100)});
      final to = _makeIndex({});
      final diff = engine.computeDiff(from, to, fromSnapshotHash: "from", toSnapshotHash: "to");
      expect(diff.deletes.length, 1);
      expect(diff.deletes.first.resourceId, "identA");
      expect(diff.adds, isEmpty);
      expect(diff.modifies, isEmpty);
    });

    test("changed content hash produces modify", () {
      final from = _makeIndex({"identA": ("hashA", 100)});
      final to = _makeIndex({"identA": ("hashB", 100)});
      final diff = engine.computeDiff(from, to, fromSnapshotHash: "from", toSnapshotHash: "to");
      expect(diff.modifies.length, 1);
      expect(diff.modifies.first.resourceId, "identA");
      expect(diff.modifies.first.contentHash, "hashB");
      expect(diff.adds, isEmpty);
      expect(diff.deletes, isEmpty);
    });

    test("changed size produces modify", () {
      final from = _makeIndex({"identA": ("hashA", 100)});
      final to = _makeIndex({"identA": ("hashA", 200)});
      final diff = engine.computeDiff(from, to, fromSnapshotHash: "from", toSnapshotHash: "to");
      expect(diff.modifies.length, 1);
    });

    test("mixed changes", () {
      final from = _makeIndex({
        "identA": ("hashA", 100),
        "identB": ("hashB", 200),
        "identC": ("hashC", 300),
      });
      final to = _makeIndex({
        "identA": ("hashA", 100), // unchanged
        "identB": ("hashB2", 200), // modified
        "identD": ("hashD", 400), // added
      });
      final diff = engine.computeDiff(from, to, fromSnapshotHash: "from", toSnapshotHash: "to");
      expect(diff.adds.length, 1);
      expect(diff.adds.first.resourceId, "identD");
      expect(diff.deletes.length, 1);
      expect(diff.deletes.first.resourceId, "identC");
      expect(diff.modifies.length, 1);
      expect(diff.modifies.first.resourceId, "identB");
    });

    test("snapshot hashes are recorded", () {
      final from = _makeIndex({});
      final to = _makeIndex({});
      final diff = engine.computeDiff(
        from,
        to,
        fromSnapshotHash: "abc123",
        toSnapshotHash: "def456",
      );
      expect(diff.fromSnapshotHash, "abc123");
      expect(diff.toSnapshotHash, "def456");
    });
  });
}
