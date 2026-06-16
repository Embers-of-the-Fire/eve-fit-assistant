import "package:eve_fit_assistant/data/proto/announcement_index.pb.dart";
import "package:eve_fit_assistant/data/proto/generation_pointer.pb.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fpdart/fpdart.dart";

sealed class AnnouncementSyncError {
  const AnnouncementSyncError();
}

class AnnouncementSyncNetworkError extends AnnouncementSyncError {
  const AnnouncementSyncNetworkError({required this.message});

  final String message;
}

/// Syncs announcement catalog with remote for a given generation.
///
/// Follows agent/schemav2/workflow.md §13.3.
class AnnouncementSyncService {
  AnnouncementSyncService({required this.remoteCatalogService, IList<String>? supportedLocales})
    : supportedLocales = supportedLocales ?? IList(const ["en", "zh"]);

  final RemoteCatalogService remoteCatalogService;
  final IList<String> supportedLocales;

  /// Fetches the announcement snapshot for [generationHash] and returns the
  /// AnnouncementIndex protobuf.
  ///
  /// Steps:
  /// 1. Fetch GenerationPointer → snapshot hash
  /// 2. Fetch AnnouncementIndex protobuf
  Future<Either<AnnouncementSyncError, ({String snapshotHash, AnnouncementIndex index})>>
  fetchForGeneration({required Channel channel, required String generationHash}) async {
    // Step 1: Get the announcement snapshot hash
    final pointerResult = await remoteCatalogService.fetchAnnouncementPointer(generationHash);
    if (pointerResult.isLeft()) {
      final err = pointerResult.getLeft().toNullable()!;
      final msg = err is CatalogNetworkError ? err.message : "Failed to fetch announcement pointer";
      return Left(AnnouncementSyncNetworkError(message: msg));
    }
    final pointer = GenerationPointer.fromBuffer(pointerResult.getRight().toNullable()!);
    final snapshotHash = pointer.snapshotHash;
    if (snapshotHash.isEmpty) {
      return const Left(
        AnnouncementSyncNetworkError(message: "Announcement pointer has no snapshot hash"),
      );
    }

    // Step 2: Fetch AnnouncementIndex
    final indexResult = await remoteCatalogService.fetchAnnouncementIndex(snapshotHash);
    if (indexResult.isLeft()) {
      final err = indexResult.getLeft().toNullable()!;
      final msg = err is CatalogNetworkError ? err.message : "Failed to fetch announcement index";
      return Left(AnnouncementSyncNetworkError(message: msg));
    }
    final index = AnnouncementIndex.fromBuffer(indexResult.getRight().toNullable()!);

    return Right((snapshotHash: snapshotHash, index: index));
  }
}
