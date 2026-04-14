import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/documents/models.dart";
import "package:path/path.dart" as p;

class DocumentStorageState {
  const DocumentStorageState({
    required this.version,
    required this.remoteCatalog,
    required this.cachedBodies,
    required this.selectedDocumentIds,
  });

  factory DocumentStorageState.initial() => DocumentStorageState(
    version: DocumentStorage.currentVersion,
    remoteCatalog: DocumentCatalog.empty(),
    cachedBodies: const <String, String>{},
    selectedDocumentIds: const <String, String>{},
  );

  factory DocumentStorageState.fromJson(Map<String, dynamic> json) {
    final version = json["version"];
    if (version is! int || version != DocumentStorage.currentVersion) {
      return DocumentStorageState.initial();
    }
    final remoteCatalogJson = json["remoteCatalog"];
    final cachedBodiesJson = json["cachedBodies"];
    final selectedDocumentIdsJson = json["selectedDocumentIds"];
    return DocumentStorageState(
      version: version,
      remoteCatalog: remoteCatalogJson is Map<String, dynamic>
          ? DocumentCatalog.fromJson(remoteCatalogJson)
          : DocumentCatalog.empty(),
      cachedBodies: cachedBodiesJson is Map<String, dynamic>
          ? cachedBodiesJson.map(
              (Object? key, Object? value) => MapEntry(key! as String, value! as String),
            )
          : const <String, String>{},
      selectedDocumentIds: selectedDocumentIdsJson is Map<String, dynamic>
          ? selectedDocumentIdsJson.map(
              (Object? key, Object? value) => MapEntry(key! as String, value! as String),
            )
          : const <String, String>{},
    );
  }

  final int version;
  final DocumentCatalog remoteCatalog;
  final Map<String, String> cachedBodies;
  final Map<String, String> selectedDocumentIds;

  Map<String, dynamic> toJson() => <String, dynamic>{
    "version": version,
    "remoteCatalog": remoteCatalog.toJson(),
    "cachedBodies": cachedBodies,
    "selectedDocumentIds": selectedDocumentIds,
  };

  DocumentStorageState copyWith({
    DocumentCatalog? remoteCatalog,
    Map<String, String>? cachedBodies,
    Map<String, String>? selectedDocumentIds,
  }) => DocumentStorageState(
    version: version,
    remoteCatalog: remoteCatalog ?? this.remoteCatalog,
    cachedBodies: cachedBodies ?? this.cachedBodies,
    selectedDocumentIds: selectedDocumentIds ?? this.selectedDocumentIds,
  );
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
      return DocumentStorageState.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } on FormatException {
      return DocumentStorageState.initial();
    } on FileSystemException {
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
