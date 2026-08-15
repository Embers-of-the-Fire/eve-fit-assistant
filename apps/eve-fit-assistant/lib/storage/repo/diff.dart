import "package:efa_proto/resource_index.pb.dart";
import "package:eve_fit_assistant/storage/repo/models/diff.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";

/// Pure computation engine for diff between two ResourceIndex protobufs.
///
/// Diffs are computed on-demand and not stored. The old stored-diff-chain
/// approach from v2 branches is replaced by direct ResourceIndex comparison.
class DiffEngine {
  const DiffEngine();

  static const _resourcePrefix = "resource://";

  /// Strips the `resource://` scheme prefix to recover the logical file path.
  static String _logicalPath(String resourceId) {
    if (resourceId.startsWith(_resourcePrefix)) return resourceId.substring(_resourcePrefix.length);
    return resourceId;
  }

  /// Computes the diff between [from] and [to] ResourceIndex protobufs.
  ///
  /// Returns a [Diff] with added, deleted, and modified entries.
  Diff computeDiff(
    ResourceIndex from,
    ResourceIndex to, {
    required String fromSnapshotHash,
    required String toSnapshotHash,
  }) {
    final fromMap = <String, ResourceIndex_Entry>{};
    for (final entry in from.entries) {
      fromMap[entry.resourceId] = entry;
    }

    final toMap = <String, ResourceIndex_Entry>{};
    for (final entry in to.entries) {
      toMap[entry.resourceId] = entry;
    }

    final adds = <DiffAdd>[];
    final deletes = <DiffDelete>[];
    final modifies = <DiffModify>[];

    // Check for deletes and modifies
    for (final entry in fromMap.entries) {
      final resourceId = entry.key;
      final fromEntry = entry.value;
      final toEntry = toMap[resourceId];
      if (toEntry == null) {
        deletes.add(
          DiffDelete(
            logicalPath: _logicalPath(resourceId),
            resourceId: resourceId,
            size: fromEntry.size.toInt(),
            contentHash: fromEntry.contentHash,
          ),
        );
      } else if (toEntry.contentHash != fromEntry.contentHash || toEntry.size != fromEntry.size) {
        modifies.add(
          DiffModify(
            logicalPath: _logicalPath(resourceId),
            resourceId: resourceId,
            contentHash: toEntry.contentHash,
            size: toEntry.size.toInt(),
          ),
        );
      }
    }

    // Check for adds
    for (final entry in toMap.entries) {
      final resourceId = entry.key;
      if (!fromMap.containsKey(resourceId)) {
        final toEntry = entry.value;
        adds.add(
          DiffAdd(
            logicalPath: _logicalPath(resourceId),
            resourceId: resourceId,
            contentHash: toEntry.contentHash,
            size: toEntry.size.toInt(),
          ),
        );
      }
    }

    return Diff(
      fromSnapshotHash: fromSnapshotHash,
      toSnapshotHash: toSnapshotHash,
      adds: adds.toIList(),
      deletes: deletes.toIList(),
      modifies: modifies.toIList(),
    );
  }
}
