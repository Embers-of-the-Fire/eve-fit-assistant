import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:isolate";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/documents/models.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:path/path.dart" as p;

part "storage.freezed.dart";
part "storage.g.dart";

@freezed
abstract class DocumentStorageState with _$DocumentStorageState {
  const factory DocumentStorageState({
    required int version,
    required DocumentCatalog remoteCatalog,
    @Default(<String, String>{}) Map<String, String> cachedBodies,
    @Default(<String, String>{}) Map<String, String> selectedDocumentIds,
    @Default(<String>[]) List<String> dismissedStartupAnnouncementIds,
    String? lastDocumentRevision,
    @Default(<String, DateTime>{}) Map<String, DateTime> readTimestamps,
    String? lastSeenAppVersion,
  }) = _DocumentStorageState;

  factory DocumentStorageState.initial() => DocumentStorageState(
    version: DocumentStorage.currentVersion,
    remoteCatalog: DocumentCatalog.empty(),
  );

  factory DocumentStorageState.fromJson(Map<String, dynamic> json) =>
      _$DocumentStorageStateFromJson(json);
}

class DocumentStorage {
  DocumentStorage._();

  static const int currentVersion = 2;
  static const String _storageFileName = "document_storage.json";
  static late DocumentStorageState _state;
  static Future<void> _pendingSync = Future<void>.value();

  static File get storageFile => File(p.join(PathProvider.settingsPath, _storageFileName));

  static DocumentStorageState get state => _state;

  static void init() {
    _state = _readState();
    _sync();
  }

  static String? selectedDocumentId(DocumentFeedKind kind) =>
      _state.selectedDocumentIds[kind.storageKey];

  static void saveSelectedDocumentId(DocumentFeedKind kind, String documentId) {
    _state = _state.copyWith(
      selectedDocumentIds: <String, String>{
        ..._state.selectedDocumentIds,
        kind.storageKey: documentId,
      },
    );
    _sync();
  }

  static bool isStartupAnnouncementDismissed(String documentId) =>
      _state.dismissedStartupAnnouncementIds.contains(documentId);

  static void dismissStartupAnnouncement(String documentId) {
    if (isStartupAnnouncementDismissed(documentId)) {
      return;
    }

    _state = _state.copyWith(
      dismissedStartupAnnouncementIds: <String>[
        ..._state.dismissedStartupAnnouncementIds,
        documentId,
      ],
    );
    _sync();
  }

  static DocumentCatalog get remoteCatalog => _state.remoteCatalog;

  static String? cachedBody(String documentId, String localeCode) =>
      _state.cachedBodies[cacheKey(documentId, localeCode)];

  static void replaceRemoteCatalog(
    DocumentCatalog catalog,
    Map<String, String> cachedBodies, {
    String? documentRevision,
  }) {
    _state = _state.copyWith(
      remoteCatalog: catalog,
      cachedBodies: cachedBodies,
      lastDocumentRevision: documentRevision ?? _state.lastDocumentRevision,
    );
    _sync();
  }

  static String? get lastDocumentRevision => _state.lastDocumentRevision;

  static Map<String, DateTime> get readTimestamps => _state.readTimestamps;

  static String? get lastSeenAppVersion => _state.lastSeenAppVersion;

  static bool isUnread(String documentId) => !_state.readTimestamps.containsKey(documentId);

  static void markRead(String documentId) {
    if (!isUnread(documentId)) {
      return;
    }
    _state = _state.copyWith(
      readTimestamps: <String, DateTime>{..._state.readTimestamps, documentId: DateTime.now()},
    );
    _sync();
  }

  static void markAllRead(Iterable<String> ids) {
    final now = DateTime.now();
    _state = _state.copyWith(
      readTimestamps: <String, DateTime>{..._state.readTimestamps, for (final id in ids) id: now},
    );
    _sync();
  }

  static void clearRead(Iterable<String> ids) {
    final remaining = Map<String, DateTime>.of(_state.readTimestamps);
    for (final id in ids) {
      remaining.remove(id);
    }
    _state = _state.copyWith(readTimestamps: remaining);
    _sync();
  }

  static void setLastSeenAppVersion(String version) {
    if (_state.lastSeenAppVersion == version) {
      return;
    }
    _state = _state.copyWith(lastSeenAppVersion: version);
    _sync();
  }

  static int _changeGeneration = 0;

  static int get changeGeneration => _changeGeneration;

  static String cacheKey(String documentId, String localeCode) => "$documentId::$localeCode";

  static DocumentStorageState _readState() {
    if (!storageFile.existsSync()) {
      return DocumentStorageState.initial();
    }
    try {
      final content = storageFile.readAsStringSync();
      final payload = jsonDecode(content);
      if (payload is! Map<String, dynamic>) {
        return DocumentStorageState.initial();
      }
      final state = DocumentStorageState.fromJson(payload);
      if (state.version != currentVersion) {
        if (state.version == 1) {
          return state.copyWith(
            version: currentVersion,
            readTimestamps: <String, DateTime>{},
            lastSeenAppVersion: null,
          );
        }
        return DocumentStorageState.initial();
      }
      return state;
    } on FormatException {
      return DocumentStorageState.initial();
    } on FileSystemException {
      return DocumentStorageState.initial();
    } on CheckedFromJsonException {
      return DocumentStorageState.initial();
    }
  }

  static void _sync() {
    final filePath = storageFile.path;
    final state = _state;
    _pendingSync = _pendingSync
        .catchError((Object _, StackTrace _) {})
        .then((_) => Isolate.run(() => _syncToDisk(filePath, state)))
        .then((_) => _changeGeneration++);
  }

  static void _syncToDisk(String filePath, DocumentStorageState state) {
    final file = File(filePath);
    final text = jsonEncode(state.toJson());
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    file.writeAsStringSync(text);
  }
}
