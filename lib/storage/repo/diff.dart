import "package:eve_fit_assistant/storage/repo/models/asset_manifest.dart";
import "package:eve_fit_assistant/storage/repo/models/diff.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";

/// Pure computation engine for diff compute, apply, and invert operations.
class DiffEngine {
  const DiffEngine();

  /// Computes the diff between [from] and [to] manifests.
  ///
  /// [fromCheckoutId] and [toCheckoutId] identify the checkout snapshots.
  Diff computeDiff(
    AssetManifest from,
    AssetManifest to, {
    required String fromCheckoutId,
    required String toCheckoutId,
    required String fromCreatedAt,
    required String toCreatedAt,
  }) {
    final adds = <DiffAdd>[];
    final deletes = <DiffDelete>[];
    final modifies = <DiffModify>[];

    for (final entry in from.files.entries) {
      final path = entry.key;
      final fromFile = entry.value;
      final toFile = to.files[path];
      if (toFile == null) {
        deletes.add(DiffDelete(path: path, pathHash: fromFile.pathHash, size: fromFile.size));
      } else if (toFile.hash != fromFile.hash || toFile.size != fromFile.size) {
        modifies.add(
          DiffModify(path: path, pathHash: toFile.pathHash, hash: toFile.hash, size: toFile.size),
        );
      }
    }

    for (final entry in to.files.entries) {
      final path = entry.key;
      if (!from.files.containsKey(path)) {
        final toFile = entry.value;
        adds.add(
          DiffAdd(path: path, pathHash: toFile.pathHash, hash: toFile.hash, size: toFile.size),
        );
      }
    }

    return Diff(
      from: fromCheckoutId,
      to: toCheckoutId,
      fromCreatedAt: fromCreatedAt,
      toCreatedAt: toCreatedAt,
      adds: adds.toIList(),
      deletes: deletes.toIList(),
      modifies: modifies.toIList(),
    );
  }

  /// Applies [diff] to [current] manifest, returning the result manifest.
  AssetManifest applyDiff(AssetManifest current, Diff diff) {
    final files = <String, AssetFile>{};
    for (final entry in current.files.entries) {
      files[entry.key] = entry.value;
    }

    for (final add in diff.adds) {
      files[add.path] = AssetFile(pathHash: add.pathHash, hash: add.hash, size: add.size);
    }

    for (final delete in diff.deletes) {
      files.remove(delete.path);
    }

    for (final modify in diff.modifies) {
      files[modify.path] = AssetFile(
        pathHash: modify.pathHash,
        hash: modify.hash,
        size: modify.size,
      );
    }

    return AssetManifest(assetsVersion: current.assetsVersion, files: IMap(files));
  }

  /// Inverts [diff] using [fromManifest] to recover original hashes.
  ///
  /// [fromManifest] is the manifest state before [diff] was applied (the "from" side).
  Diff invertDiff(Diff diff, AssetManifest fromManifest) {
    final adds = <DiffAdd>[];
    final deletes = <DiffDelete>[];
    final modifies = <DiffModify>[];

    for (final add in diff.adds) {
      deletes.add(
        DiffDelete(path: add.path, pathHash: add.pathHash, size: add.size, hash: add.hash),
      );
    }

    for (final delete in diff.deletes) {
      final original = fromManifest.files[delete.path];
      if (original == null) {
        throw StateError(
          "invertDiff: file '${delete.path}' not found in fromManifest — cannot invert delete",
        );
      }
      adds.add(
        DiffAdd(
          path: delete.path,
          pathHash: delete.pathHash,
          hash: original.hash,
          size: original.size,
        ),
      );
    }

    for (final modify in diff.modifies) {
      final original = fromManifest.files[modify.path];
      if (original == null) {
        throw StateError(
          "invertDiff: file '${modify.path}' not found in fromManifest — cannot invert modify",
        );
      }
      modifies.add(
        DiffModify(
          path: modify.path,
          pathHash: modify.pathHash,
          hash: original.hash,
          size: original.size,
        ),
      );
    }

    return Diff(
      from: diff.to,
      to: diff.from,
      fromCreatedAt: diff.toCreatedAt,
      toCreatedAt: diff.fromCreatedAt,
      adds: adds.toIList(),
      deletes: deletes.toIList(),
      modifies: modifies.toIList(),
    );
  }
}
