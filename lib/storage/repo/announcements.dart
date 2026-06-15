import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:crypto/crypto.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/repo/models/announcement.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fpdart/fpdart.dart";

class AnnouncementService {
  const AnnouncementService();

  static const int _indexSchemaVersion = 2;

  AnnouncementIndex readIndex() {
    final file = File(RepoPaths.announcementsIndexPath);
    if (!file.existsSync()) {
      return const AnnouncementIndex(schemaVersion: _indexSchemaVersion);
    }
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return AnnouncementIndex.fromJson(json);
    } on Exception catch (e, stackTrace) {
      warning("Failed to read announcement index", stackTrace: stackTrace);
      return const AnnouncementIndex(schemaVersion: _indexSchemaVersion);
    }
  }

  void writeIndex(AnnouncementIndex index) {
    final path = RepoPaths.announcementsIndexPath;
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final tmp = File("$path.tmp");
    try {
      tmp
        ..writeAsStringSync(jsonEncode(index.toJson()), flush: true)
        ..renameSync(path);
    } on FileSystemException catch (e, stackTrace) {
      warning("Failed to write announcement index", stackTrace: stackTrace);
      rethrow;
    }
  }

  Option<AnnouncementRecord> readRecord(String id) {
    final file = File(RepoPaths.announcementRegistryPath(id));
    if (!file.existsSync()) return const None();
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return Some(AnnouncementRecord.fromJson(json));
    } on Exception catch (e, stackTrace) {
      warning("Failed to read announcement record $id", stackTrace: stackTrace);
      return const None();
    }
  }

  void writeRecord(AnnouncementRecord record) {
    final path = RepoPaths.announcementRegistryPath(record.id);
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final tmp = File("$path.tmp");
    try {
      tmp
        ..writeAsStringSync(jsonEncode(record.toJson()), flush: true)
        ..renameSync(path);
    } on FileSystemException catch (e, stackTrace) {
      warning("Failed to write announcement record ${record.id}", stackTrace: stackTrace);
      rethrow;
    }
  }

  Option<String> readContent(String locale, String id) {
    final file = File(RepoPaths.announcementFilePath(locale, id));
    if (!file.existsSync()) return const None();
    try {
      return Some(file.readAsStringSync());
    } on Exception catch (e, stackTrace) {
      warning("Failed to read announcement content $locale/$id", stackTrace: stackTrace);
      return const None();
    }
  }

  void writeContent(String locale, String id, String markdown) {
    final path = RepoPaths.announcementFilePath(locale, id);
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final tmp = File("$path.tmp");
    try {
      tmp
        ..writeAsStringSync(markdown, flush: true)
        ..renameSync(path);
    } on FileSystemException catch (e, stackTrace) {
      warning("Failed to write announcement content $locale/$id", stackTrace: stackTrace);
      rethrow;
    }
  }

  String computeContentHash(AnnouncementRecord record, Map<String, String> localeContents) {
    final idHash = sha256.convert(utf8.encode(record.id)).toString();

    final xorResult = _xorLocaleHashes(localeContents);
    final xorHex = _uint8ListToHex(xorResult);

    final combined = "$idHash:${record.updatedAt}:$xorHex";
    return sha256.convert(utf8.encode(combined)).toString();
  }

  void updateAnnouncementIndex(String id, {bool? isVersionUpdate, String? contentHash}) {
    final index = readIndex();
    final existingEntryIndex = index.records.indexWhere((e) => e.id == id);

    if (existingEntryIndex >= 0) {
      final existing = index.records[existingEntryIndex];
      final updatedEntry = existing.copyWith(
        isVersionUpdate: isVersionUpdate ?? existing.isVersionUpdate,
        contentHash: contentHash ?? existing.contentHash,
      );
      final updatedRecords = IList(index.records.toList()..[existingEntryIndex] = updatedEntry);
      final updatedIndex = index.copyWith(records: updatedRecords);
      writeIndex(updatedIndex);
    } else {
      final newEntry = AnnouncementIndexEntry(
        id: id,
        contentHash: contentHash ?? "",
        isVersionUpdate: isVersionUpdate ?? false,
      );
      final updatedIndex = index.copyWith(records: index.records.add(newEntry));
      writeIndex(updatedIndex);
    }
  }

  void markRead(String id) {
    final index = readIndex();
    final existingEntryIndex = index.records.indexWhere((e) => e.id == id);

    if (existingEntryIndex < 0) return;

    final existing = index.records[existingEntryIndex];
    if (existing.isRead) return;

    final updatedEntry = existing.copyWith(isRead: true);
    final updatedRecords = IList(index.records.toList()..[existingEntryIndex] = updatedEntry);
    final updatedIndex = index.copyWith(records: updatedRecords);
    writeIndex(updatedIndex);
  }

  // ── Private helpers ───────────────────────────────────────────────────────────

  static Uint8List _xorLocaleHashes(Map<String, String> localeContents) {
    if (localeContents.isEmpty) return Uint8List(32);

    final entries = localeContents.entries.toList();
    var result = Uint8List.fromList(sha256.convert(utf8.encode(entries.first.value)).bytes);
    for (var i = 1; i < entries.length; i++) {
      final bytes = Uint8List.fromList(sha256.convert(utf8.encode(entries[i].value)).bytes);
      result = _xorBytes(result, bytes);
    }
    return result;
  }

  static Uint8List _xorBytes(Uint8List a, Uint8List b) {
    final result = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      result[i] = a[i] ^ b[i];
    }
    return result;
  }

  static String _uint8ListToHex(Uint8List bytes) {
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, "0"));
    }
    return buffer.toString();
  }
}
