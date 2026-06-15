import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/models/announcement.dart";
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

class AnnouncementSyncStorageError extends AnnouncementSyncError {
  const AnnouncementSyncStorageError({required this.message});

  final String message;
}

class AnnouncementSyncService {
  const AnnouncementSyncService({
    required this.remoteCatalogService,
    required this.localIndexPath,
    required this.supportedLocales,
  });

  final RemoteCatalogService remoteCatalogService;
  final String localIndexPath;
  final IList<String> supportedLocales;

  String get _indexPath => "$localIndexPath/index.json";

  String _registryPath(String id) => "$localIndexPath/registry/$id.json";

  String _filePath(String locale, String id) => "$localIndexPath/files/$locale/$id";

  /// Runs the full announcement sync for [channel], returning a list of
  /// announcement IDs that were new or updated.
  Future<Either<AnnouncementSyncError, IList<String>>> sync(Channel channel) async {
    final manifestResult = await remoteCatalogService.fetchManifestIndex(channel);
    if (manifestResult.isLeft()) {
      final err = manifestResult.getLeft().toNullable()!;
      final msg = err is CatalogNetworkError ? err.message : "Failed to fetch manifest";
      return Left(AnnouncementSyncNetworkError(message: msg));
    }
    final generationId = manifestResult.getRight().toNullable()!.activatedGeneration;

    final catalogResult = await remoteCatalogService.fetchAnnouncementCatalog(
      channel,
      generationId,
    );
    if (catalogResult.isLeft()) {
      final err = catalogResult.getLeft().toNullable()!;
      final msg = err is CatalogNetworkError ? err.message : "Failed to fetch catalog";
      return Left(AnnouncementSyncNetworkError(message: msg));
    }
    final catalog = catalogResult.getRight().toNullable()!;

    final localIndex = readLocalIndex().getOrElse(() => const AnnouncementIndex(schemaVersion: 2));
    final localRecords = <String, AnnouncementIndexEntry>{};
    for (final entry in localIndex.records) {
      localRecords[entry.id] = entry;
    }

    final changedIds = <String>[];
    final updatedRecords = <String, AnnouncementIndexEntry>{};
    for (final entry in localIndex.records) {
      updatedRecords[entry.id] = entry;
    }

    for (final catalogEntry in catalog.announcements.values) {
      final localRecord = localRecords[catalogEntry.id];
      final needsFetch = localRecord == null || localRecord.contentHash != catalogEntry.contentHash;

      if (needsFetch) {
        final recordResult = await remoteCatalogService.fetchAnnouncementRecord(
          channel,
          catalogEntry.id,
        );
        if (recordResult.isLeft()) {
          final err = recordResult.getLeft().toNullable()!;
          final msg = err is CatalogNetworkError
              ? err.message
              : "Failed to fetch record ${catalogEntry.id}";
          return Left(AnnouncementSyncNetworkError(message: msg));
        }
        final record = recordResult.getRight().toNullable()!;

        final localeContents = <String, String>{};
        var contentFailed = false;
        for (final locale in supportedLocales) {
          final contentResult = await remoteCatalogService.fetchAnnouncementContent(
            channel,
            locale,
            catalogEntry.id,
          );
          if (contentResult.isRight()) {
            localeContents[locale] = contentResult.getRight().toNullable()!;
          } else {
            contentFailed = true;
          }
        }

        if (contentFailed) continue;

        try {
          writeLocalRecord(record);
          for (final MapEntry(:key, :value) in localeContents.entries) {
            writeLocalContent(key, record.id, value);
          }
        } on FileSystemException catch (e) {
          return Left(AnnouncementSyncStorageError(message: e.message));
        }

        updatedRecords[catalogEntry.id] = AnnouncementIndexEntry(
          id: catalogEntry.id,
          contentHash: catalogEntry.contentHash,
          isVersionUpdate: catalogEntry.isVersionUpdate,
        );

        changedIds.add(catalogEntry.id);
      }
    }

    try {
      writeLocalIndex(
        AnnouncementIndex(
          schemaVersion: localIndex.schemaVersion,
          records: IList(updatedRecords.values.toList()),
        ),
      );
    } on FileSystemException catch (e) {
      return Left(AnnouncementSyncStorageError(message: e.message));
    }

    return Right(IList(changedIds));
  }

  Option<AnnouncementIndex> readLocalIndex() {
    final file = File(_indexPath);
    if (!file.existsSync()) return const None();
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return Some(AnnouncementIndex.fromJson(json));
    } on Exception catch (e, stackTrace) {
      warning("Failed to read local announcement index", stackTrace: stackTrace);
      return const None();
    }
  }

  void writeLocalIndex(AnnouncementIndex index) {
    _atomicWrite(_indexPath, jsonEncode(index.toJson()));
  }

  Option<AnnouncementRecord> readLocalRecord(String id) {
    final file = File(_registryPath(id));
    if (!file.existsSync()) return const None();
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return Some(AnnouncementRecord.fromJson(json));
    } on Exception catch (e, stackTrace) {
      warning("Failed to read local announcement record $id", stackTrace: stackTrace);
      return const None();
    }
  }

  void writeLocalRecord(AnnouncementRecord record) {
    _atomicWrite(_registryPath(record.id), jsonEncode(record.toJson()));
  }

  Option<String> readLocalContent(String locale, String id) {
    final file = File(_filePath(locale, id));
    if (!file.existsSync()) return const None();
    try {
      return Some(file.readAsStringSync());
    } on Exception catch (e, stackTrace) {
      warning("Failed to read local announcement content $locale/$id", stackTrace: stackTrace);
      return const None();
    }
  }

  void writeLocalContent(String locale, String id, String content) {
    _atomicWrite(_filePath(locale, id), content);
  }

  void _atomicWrite(String path, String content) {
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final tmp = File("$path.tmp");
    try {
      tmp
        ..writeAsStringSync(content, flush: true)
        ..renameSync(path);
    } on FileSystemException catch (e, stackTrace) {
      warning("Failed to atomic write $path", stackTrace: stackTrace);
      rethrow;
    }
  }
}
