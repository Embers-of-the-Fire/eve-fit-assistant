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

  static const int currentVersion = 1;
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
      _state.cachedBodies[_cacheKey(documentId, localeCode)];

  static void replaceRemoteCatalog(DocumentCatalog catalog, Map<String, String> cachedBodies) {
    _state = _state.copyWith(remoteCatalog: catalog, cachedBodies: cachedBodies);
    _sync();
  }

  static String _cacheKey(String documentId, String localeCode) => "$documentId::$localeCode";

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
        .then((_) => Isolate.run(() => _syncToDisk(filePath, state)));
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
