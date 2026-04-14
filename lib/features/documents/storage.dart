import "dart:convert";
import "dart:io";

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
      final state = DocumentStorageState.fromJson(jsonDecode(content) as Map<String, dynamic>);
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
    if (!storageFile.existsSync()) {
      storageFile.createSync(recursive: true);
    }
    storageFile.writeAsStringSync(jsonEncode(_state.toJson()));
  }
}
