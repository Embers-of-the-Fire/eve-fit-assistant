import "package:eve_fit_assistant/storage/repo/diff.dart";
import "package:eve_fit_assistant/storage/repo/models/asset_manifest.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";

AssetFile mf(String pathHash, String hash, int size) =>
    AssetFile(pathHash: pathHash, hash: hash, size: size);

AssetManifest manifest(Map<String, AssetFile> files) =>
    AssetManifest(assetsVersion: 1, files: IMap(files));

void main() {
  const engine = DiffEngine();

  final emptyManifest = manifest({});

  final manifestA = manifest({"a": mf("ph_a", "h_a1", 10), "b": mf("ph_b", "h_b1", 20)});

  final manifestB = manifest({
    "a": mf("ph_a", "h_a1", 10),
    "b": mf("ph_b", "h_b2", 25),
    "c": mf("ph_c", "h_c1", 30),
  });

  group("DiffEngine.computeDiff", () {
    test("empty to non-empty produces add-only diff", () {
      final diff = engine.computeDiff(
        emptyManifest,
        manifestA,
        fromCheckoutId: "from",
        toCheckoutId: "to",
        fromCreatedAt: "2024-01-01T00:00:00Z",
        toCreatedAt: "2024-01-02T00:00:00Z",
      );

      expect(diff.adds.length, 2);
      expect(diff.deletes.length, 0);
      expect(diff.modifies.length, 0);

      final addPaths = diff.adds.map((a) => a.path).toSet();
      expect(addPaths, {"a", "b"});
    });

    test("non-empty to empty produces delete-only diff", () {
      final diff = engine.computeDiff(
        manifestA,
        emptyManifest,
        fromCheckoutId: "from",
        toCheckoutId: "to",
        fromCreatedAt: "2024-01-01T00:00:00Z",
        toCreatedAt: "2024-01-02T00:00:00Z",
      );

      expect(diff.adds.length, 0);
      expect(diff.deletes.length, 2);
      expect(diff.modifies.length, 0);

      final delPaths = diff.deletes.map((d) => d.path).toSet();
      expect(delPaths, {"a", "b"});
    });

    test("add-only diff (new file)", () {
      final diff = engine.computeDiff(
        manifestA,
        manifestB,
        fromCheckoutId: "A",
        toCheckoutId: "B",
        fromCreatedAt: "2024-01-01T00:00:00Z",
        toCreatedAt: "2024-01-02T00:00:00Z",
      );

      expect(diff.adds.length, 1);
      expect(diff.adds.first.path, "c");
      expect(diff.adds.first.hash, "h_c1");
    });

    test("modify-only diff (changed file)", () {
      final diff = engine.computeDiff(
        manifestA,
        manifestB,
        fromCheckoutId: "A",
        toCheckoutId: "B",
        fromCreatedAt: "2024-01-01T00:00:00Z",
        toCreatedAt: "2024-01-02T00:00:00Z",
      );

      expect(diff.modifies.length, 1);
      expect(diff.modifies.first.path, "b");
      expect(diff.modifies.first.hash, "h_b2");
      expect(diff.modifies.first.size, 25);
    });

    test("same manifest produces no changes", () {
      final diff = engine.computeDiff(
        manifestA,
        manifestA,
        fromCheckoutId: "A",
        toCheckoutId: "A",
        fromCreatedAt: "2024-01-01T00:00:00Z",
        toCreatedAt: "2024-01-01T00:00:00Z",
      );

      expect(diff.adds.length, 0);
      expect(diff.deletes.length, 0);
      expect(diff.modifies.length, 0);
    });

    test("preserves checkout metadata", () {
      final diff = engine.computeDiff(
        manifestA,
        manifestB,
        fromCheckoutId: "chk_A",
        toCheckoutId: "chk_B",
        fromCreatedAt: "2024-06-01T12:00:00Z",
        toCreatedAt: "2024-06-02T12:00:00Z",
      );

      expect(diff.from, "chk_A");
      expect(diff.to, "chk_B");
      expect(diff.fromCreatedAt, "2024-06-01T12:00:00Z");
      expect(diff.toCreatedAt, "2024-06-02T12:00:00Z");
    });
  });

  group("DiffEngine.applyDiff", () {
    test("applying add-only diff yields target manifest", () {
      final diff = engine.computeDiff(
        manifestA,
        manifestB,
        fromCheckoutId: "A",
        toCheckoutId: "B",
        fromCreatedAt: "2024-01-01T00:00:00Z",
        toCreatedAt: "2024-01-02T00:00:00Z",
      );

      final result = engine.applyDiff(manifestA, diff);

      expect(result.files.length, 3);
      expect(result.files["c"]?.hash, "h_c1");
    });

    test("applying delete-only diff removes files", () {
      final diff = engine.computeDiff(
        manifestB,
        manifestA,
        fromCheckoutId: "B",
        toCheckoutId: "A",
        fromCreatedAt: "2024-01-02T00:00:00Z",
        toCreatedAt: "2024-01-01T00:00:00Z",
      );

      final result = engine.applyDiff(manifestB, diff);

      expect(result.files.length, 2);
      expect(result.files.containsKey("c"), isFalse);
    });

    test("apply empty→nonempty on empty base yields the target", () {
      final diff = engine.computeDiff(
        emptyManifest,
        manifestA,
        fromCheckoutId: "empty",
        toCheckoutId: "A",
        fromCreatedAt: "2024-01-01T00:00:00Z",
        toCreatedAt: "2024-01-01T00:00:00Z",
      );

      final result = engine.applyDiff(emptyManifest, diff);

      expect(result.files.length, 2);
      expect(result.files["a"]?.hash, "h_a1");
    });
  });

  group("DiffEngine.invertDiff", () {
    test("throws StateError when fromManifest missing file referenced by delete", () {
      // Invert a diff that deletes "b" (A->B has no delete, but B->emptyManifest does)
      final forwardToEmpty = engine.computeDiff(
        manifestB,
        emptyManifest,
        fromCheckoutId: "B",
        toCheckoutId: "empty",
        fromCreatedAt: "2024-01-02T00:00:00Z",
        toCreatedAt: "2024-01-03T00:00:00Z",
      );
      // Passing manifestA (missing "c") as fromManifest for a diff that deletes "c" should throw
      expect(
        () => engine.invertDiff(forwardToEmpty, manifestA),
        throwsA(
          isA<StateError>().having((e) => e.message, "message", contains("invertDiff: file")),
        ),
      );
    });

    test("throws StateError when fromManifest missing file referenced by modify", () {
      final forward = engine.computeDiff(
        manifestA,
        manifestB,
        fromCheckoutId: "A",
        toCheckoutId: "B",
        fromCreatedAt: "2024-01-01T00:00:00Z",
        toCreatedAt: "2024-01-02T00:00:00Z",
      );
      // Passing emptyManifest as fromManifest — missing both "b" (modify) and "a" — should throw
      expect(
        () => engine.invertDiff(forward, emptyManifest),
        throwsA(
          isA<StateError>().having((e) => e.message, "message", contains("invertDiff: file")),
        ),
      );
    });

    test("inverting add-only diff produces delete-only diff with propagated hash", () {
      final forward = engine.computeDiff(
        manifestA,
        manifestB,
        fromCheckoutId: "A",
        toCheckoutId: "B",
        fromCreatedAt: "2024-01-01T00:00:00Z",
        toCreatedAt: "2024-01-02T00:00:00Z",
      );

      final inverted = engine.invertDiff(forward, manifestA);

      expect(inverted.from, "B");
      expect(inverted.to, "A");
      expect(inverted.adds.length, 0);
      // The add (c) becomes a delete, with the content hash propagated
      expect(inverted.deletes.length, 1);
      expect(inverted.deletes.first.path, "c");
      expect(inverted.deletes.first.hash, "h_c1");
    });

    test("inverting modify diff recovers original hash", () {
      final forward = engine.computeDiff(
        manifestA,
        manifestB,
        fromCheckoutId: "A",
        toCheckoutId: "B",
        fromCreatedAt: "2024-01-01T00:00:00Z",
        toCreatedAt: "2024-01-02T00:00:00Z",
      );

      final inverted = engine.invertDiff(forward, manifestA);

      final modifyBack = inverted.modifies.firstWhere((m) => m.path == "b");
      expect(modifyBack.hash, "h_b1");
      expect(modifyBack.size, 20);
    });

    test("applying inverted diff returns to original state", () {
      final forward = engine.computeDiff(
        manifestA,
        manifestB,
        fromCheckoutId: "A",
        toCheckoutId: "B",
        fromCreatedAt: "2024-01-01T00:00:00Z",
        toCreatedAt: "2024-01-02T00:00:00Z",
      );

      final inverted = engine.invertDiff(forward, manifestA);
      final restored = engine.applyDiff(manifestB, inverted);

      expect(restored.files.length, manifestA.files.length);
      for (final key in manifestA.files.keys) {
        expect(restored.files[key], manifestA.files[key]);
      }
    });
  });
}
