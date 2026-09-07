import "package:efa_proto/resource_index.pb.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/resource_resolution.dart";

/// One eager blob to download during provisioning, with its precomputed
/// identity and store path so the download hot loop is allocation-free.
typedef ProvisioningBlob = ({
  ResourceIndex_Entry entry,
  String identHash,
  String blobPath,
  int size,
});

/// Resolution-aware partition of resource index entries for provisioning.
///
/// Shared by every creation flow (welcome wizard, checkout creation) so all
/// of them apply the same Resource Resolution Schema semantics as data
/// updates: entries resolving to `lazy` are skipped and fetched on first
/// access, `excluded` entries are never listed, and only `eager` entries are
/// downloaded ahead of time.
class ProvisioningWorkList {
  const ProvisioningWorkList({
    required this.toDownload,
    required this.cachedCount,
    required this.cachedBytes,
    required this.totalBytes,
    required this.totalEntries,
  });

  /// Eager blobs absent from the store, sorted largest-first so big blobs
  /// start downloading early.
  final List<ProvisioningBlob> toDownload;

  /// Eager blobs already present in the store.
  final int cachedCount;
  final int cachedBytes;

  /// Total size of all eager blobs (cached + to download).
  final int totalBytes;

  /// Count of all eager blobs (cached + to download).
  final int totalEntries;
}

/// Partitions the eager entries of [indexes] into cached vs. to-download.
///
/// Entries are deduplicated by blob identity (identHash, contentHash) across
/// [indexes], so multi-server provisioning downloads each stored blob exactly
/// once. Each entry is resolved against the RRS with [context]; only entries
/// resolving to [ResourceResolution.eager] contribute.
Future<ProvisioningWorkList> computeEagerWorkList(
  AssetStore assetStore,
  Iterable<ResourceIndex> indexes, {
  required ResourceResolutionContext context,
}) async {
  final toDownload = <ProvisioningBlob>[];
  final seen = <String>{};
  var cachedCount = 0;
  var cachedBytes = 0;
  var totalBytes = 0;
  var totalEntries = 0;

  for (final index in indexes) {
    for (final entry in index.entries) {
      if (resolveResource(index, entry, context) != ResourceResolution.eager) continue;
      final identHash = RepoHash.hashIdent(entry.resourceId);
      if (!seen.add("$identHash/${entry.contentHash}")) continue;
      final size = entry.size.toInt();
      totalBytes += size;
      totalEntries++;
      if (await assetStore.blobExists(identHash, entry.contentHash)) {
        cachedCount++;
        cachedBytes += size;
      } else {
        toDownload.add((
          entry: entry,
          identHash: identHash,
          blobPath: RepoPaths.blobPath(identHash, entry.contentHash),
          size: size,
        ));
      }
    }
  }

  toDownload.sort((a, b) => b.size.compareTo(a.size));

  return ProvisioningWorkList(
    toDownload: toDownload,
    cachedCount: cachedCount,
    cachedBytes: cachedBytes,
    totalBytes: totalBytes,
    totalEntries: totalEntries,
  );
}
