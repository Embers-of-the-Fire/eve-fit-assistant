import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/data/proto/announcement_index.pb.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/models/blob_ident.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/utils.dart";
import "package:fpdart/fpdart.dart";

/// Manages announcement index, content, and read state.
///
/// Uses the AnnouncementIndex protobuf from the generation chain
/// and stores snapshots in `announcements/{snapshotHash}/`.
/// Content blobs are stored in the shared `assets/blobs/` store
/// via `announcement://` idents (spec §4.4).
class AnnouncementService {
  const AnnouncementService();

  /// Saves an announcement snapshot to disk atomically.
  ///
  /// Writes metadata.json and announcements.pb2 to a temp directory, then
  /// renames to `announcements/{snapshotHash}/` (spec §11.1).
  void saveAnnouncementSnapshot(String snapshotHash, AnnouncementIndex index) {
    final targetDir = Directory(RepoPaths.announcementSnapshotPath(snapshotHash));
    if (targetDir.existsSync()) return;

    final tempDir = Directory("${RepoPaths.schemaResourcesPath}/tmp_announcement_snapshot");
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    tempDir.createSync(recursive: true);

    // Write announcements.pb2
    final indexPath = "${tempDir.path}/announcements.pb2";
    writeProtobufSync(indexPath, index);

    // Write metadata.json
    final metaPath = "${tempDir.path}/metadata.json";
    final meta = {
      "schemaVersion": 1,
      "announcementCount": index.entries.length,
      "createdAt": DateTime.now().toUtc().toIso8601String(),
    };
    File(metaPath).writeAsStringSync(jsonEncode(meta), flush: true);

    targetDir.parent.createSync(recursive: true);
    tempDir.renameSync(targetDir.path);
  }

  /// Reads a cached AnnouncementIndex.
  ///
  /// Returns [None] if not present.
  Option<AnnouncementIndex> readCachedIndex(String snapshotHash) {
    final indexPath = RepoPaths.announcementIndexPath(snapshotHash);
    final file = File(indexPath);
    if (!file.existsSync()) return const None();
    try {
      return Some(AnnouncementIndex.fromBuffer(file.readAsBytesSync()));
    } on Exception {
      return const None();
    }
  }

  /// Caches announcement content as a blob in the shared `assets/blobs/` store.
  ///
  /// The ident_hash is computed from `announcement://{locale}/{id}`.
  /// The content_hash is computed from [content] bytes.
  /// Returns the content_hash so the caller can cross-check against the
  /// AnnouncementIndex entry.
  void cacheContent(String locale, String announcementId, String content) {
    final ident = BlobIdent.announcement(locale, announcementId);
    final contentBytes = utf8.encode(content);
    final contentHash = RepoHash.hashContent(Uint8List.fromList(contentBytes));
    final blobPath = RepoPaths.blobPath(ident.identHash, contentHash);

    final file = File(blobPath);
    if (file.existsSync()) return;

    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final tmp = File("$blobPath.tmp");
    try {
      tmp
        ..writeAsBytesSync(contentBytes, flush: true)
        ..renameSync(blobPath);
    } on FileSystemException catch (e, stackTrace) {
      warning("Failed to cache announcement blob $locale/$announcementId", stackTrace: stackTrace);
    }
  }

  /// Reads cached announcement content from the blob store.
  ///
  /// [contentHash] must match the value from the AnnouncementIndex entry's
  /// content_hashes map for the given locale.
  Option<String> readCachedContent(String locale, String announcementId, String contentHash) {
    final ident = BlobIdent.announcement(locale, announcementId);
    final blobPath = RepoPaths.blobPath(ident.identHash, contentHash);
    final file = File(blobPath);
    if (!file.existsSync()) return const None();
    try {
      return Some(utf8.decode(file.readAsBytesSync()));
    } on Exception {
      return const None();
    }
  }
}
