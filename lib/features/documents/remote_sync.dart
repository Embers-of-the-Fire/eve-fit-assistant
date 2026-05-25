import "dart:async";
import "dart:convert";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/documents/models.dart";
import "package:eve_fit_assistant/features/documents/repository.dart";
import "package:eve_fit_assistant/features/documents/storage.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";
import "package:eve_fit_assistant/features/remote_content/endpoint.dart";
import "package:eve_fit_assistant/features/remote_content/etag_cache.dart";
import "package:eve_fit_assistant/features/remote_content/http.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

const Set<String> _supportedKinds = <String>{"announcement", "information", "version"};

final remoteDocumentSyncServiceProvider = Provider<RemoteDocumentSyncService>(
  (Ref ref) => RemoteDocumentSyncService(ref: ref),
);

class RemoteDocumentSyncService {
  RemoteDocumentSyncService({required Ref ref, Dio? dio})
    : _ref = ref,
      _dio = dio ?? createRemoteDio();

  final Ref _ref;
  final Dio _dio;

  Future<bool> sync() async {
    final config = _ref.read(appSettingServiceProvider).remoteContent;
    if (!config.enabled) {
      return false;
    }

    try {
      final endpoint = RemoteContentEndpoint.fromSetting(config);

      if (DocumentStorage.lastDocumentRevision == null) {
        EtagCache.remove(endpoint.indexUri);
      }

      final indexResult = await getRemoteUri<String>(_dio, endpoint.indexUri);
      if (indexResult.notModified) {
        info("Remote document index unchanged; skipping sync.");
        return true;
      }
      final indexText = indexResult.response.data;
      if (indexText == null || indexText.isEmpty) {
        throw const RemoteContentException("Remote index response body is empty.");
      }
      final index = jsonDecode(indexText) as Map<String, dynamic>;
      final documentCatalogPath = _readDocumentCatalogPath(index, endpoint.channel);
      if (documentCatalogPath == null) {
        return false;
      }

      final documents = index["documents"] as Map<String, dynamic>?;
      final documentRevision = documents?["revision"] as String?;
      if (documentRevision != null && documentRevision == DocumentStorage.lastDocumentRevision) {
        info("Remote document revision unchanged ($documentRevision); skipping catalog fetch.");
        return true;
      }

      final catalogUri = endpoint.resolvePayloadUri(documentCatalogPath);
      final catalogPayload = await fetchRemoteJson(_dio, catalogUri);
      final parsedCatalog = await _parseCatalog(catalogPayload, endpoint);
      DocumentStorage.replaceRemoteCatalog(
        parsedCatalog.catalog,
        parsedCatalog.cachedBodies,
        documentRevision: documentRevision,
      );
      _ref.invalidate(documentFeedProvider);
      info("Synced ${parsedCatalog.catalog.entries.length} remote document entries.");
      return true;
    } on Object catch (exception, stackTrace) {
      warning("Remote document sync failed: $exception", stackTrace: stackTrace);
      return false;
    }
  }

  String? _readDocumentCatalogPath(Map<String, dynamic> index, String expectedChannel) {
    expectRemoteInt(index, "schemaVersion", remoteContentSchemaVersion);
    final minClientApi = readRemoteRequiredInt(index, "minClientApi");
    if (minClientApi > remoteContentClientApiVersion) {
      throw RemoteContentException(
        "Remote index requires API $minClientApi, client supports $remoteContentClientApiVersion.",
      );
    }
    final channel = readRemoteRequiredString(index, "channel");
    if (channel != expectedChannel) {
      throw RemoteContentException(
        "Remote index channel '$channel' does not match '$expectedChannel'.",
      );
    }
    final documents = index["documents"];
    if (documents == null) {
      return null;
    }
    if (documents is! Map<String, dynamic>) {
      throw const RemoteContentException("Remote index documents section is invalid.");
    }
    return readRemoteRequiredString(documents, "catalogPath");
  }

  Future<({DocumentCatalog catalog, Map<String, String> cachedBodies})> _parseCatalog(
    Map<String, dynamic> payload,
    RemoteContentEndpoint endpoint,
  ) async {
    expectRemoteInt(payload, "schemaVersion", remoteContentSchemaVersion);
    final catalogVersion = readRemoteRequiredInt(payload, "version");
    final rawEntries = payload["entries"];
    if (rawEntries is! List<Object?>) {
      throw const RemoteContentException("Remote document catalog entries must be a list.");
    }

    final oldCatalog = DocumentStorage.remoteCatalog;
    final oldEntries = <String, DocumentEntry>{};
    for (final oldEntry in oldCatalog.entries) {
      oldEntries[oldEntry.id] = oldEntry;
    }

    final entries = <DocumentEntry>[];
    final cachedBodies = <String, String>{};
    final seenIds = <String>{};

    for (final rawEntry in rawEntries) {
      if (rawEntry is! Map<String, dynamic>) {
        throw const RemoteContentException("Remote document entry must be an object.");
      }
      final parsedEntry = await _parseEntry(rawEntry, endpoint, oldEntries: oldEntries);
      if (!seenIds.add(parsedEntry.entry.id)) {
        throw RemoteContentException("Duplicate remote document id: ${parsedEntry.entry.id}");
      }
      entries.add(parsedEntry.entry);
      cachedBodies.addAll(parsedEntry.cachedBodies);
    }

    return (
      catalog: DocumentCatalog(version: catalogVersion, entries: entries),
      cachedBodies: cachedBodies,
    );
  }

  Future<({DocumentEntry entry, Map<String, String> cachedBodies})> _parseEntry(
    Map<String, dynamic> payload,
    RemoteContentEndpoint endpoint, {
    Map<String, DocumentEntry>? oldEntries,
  }) async {
    final id = readRemoteRequiredString(payload, "id");
    _validateDocumentId(id);
    final kind = readRemoteRequiredString(payload, "kind");
    if (!_supportedKinds.contains(kind)) {
      throw RemoteContentException("Unsupported remote document kind '$kind' for '$id'.");
    }
    final source = readRemoteRequiredString(payload, "source");
    if (source != "remote") {
      throw RemoteContentException("Remote document '$id' must use source 'remote'.");
    }
    final publishedAt = DateTime.tryParse(readRemoteRequiredString(payload, "publishedAt"));
    if (publishedAt == null) {
      throw RemoteContentException("Remote document '$id' has invalid publishedAt.");
    }
    final oldEntry = oldEntries?[id];
    final localizations = await _parseLocalizations(payload, endpoint, id, oldEntry: oldEntry);

    return (
      entry: DocumentEntry(
        id: id,
        kind: DocumentEntryKind.values.byName(kind),
        source: DocumentEntrySource.remote,
        publishedAt: publishedAt,
        localizations: localizations.localizations,
        tags: readRemoteOptionalStringList(payload, "tags"),
        startup: readRemoteOptionalBool(payload, "startup"),
        minAppVer: readRemoteOptionalString(payload, "minAppVer"),
        appVer: readRemoteOptionalString(payload, "appVer"),
      ),
      cachedBodies: localizations.cachedBodies,
    );
  }

  Future<({Map<String, DocumentLocalization> localizations, Map<String, String> cachedBodies})>
  _parseLocalizations(
    Map<String, dynamic> payload,
    RemoteContentEndpoint endpoint,
    String documentId, {
    DocumentEntry? oldEntry,
  }) async {
    final rawLocalizations = payload["localizations"];
    if (rawLocalizations is! Map<String, dynamic> || rawLocalizations.isEmpty) {
      throw RemoteContentException("Remote document '$documentId' has no localizations.");
    }

    final localizations = <String, DocumentLocalization>{};
    final cachedBodies = <String, String>{};
    for (final MapEntry<String, dynamic> item in rawLocalizations.entries) {
      final localeCode = _normalizeLocaleCode(item.key);
      if (localizations.containsKey(localeCode)) {
        throw RemoteContentException(
          "Remote document '$documentId' has duplicate locale '$localeCode'.",
        );
      }
      if (item.value is! Map<String, dynamic>) {
        throw RemoteContentException(
          "Remote document '$documentId' localization '$localeCode' is invalid.",
        );
      }
      final localization = item.value as Map<String, dynamic>;
      final title = readRemoteRequiredString(localization, "title");
      final summary = readRemoteRequiredString(localization, "summary");
      final cacheKey = DocumentStorage.cacheKey(documentId, localeCode);

      final oldLocaleExists = oldEntry?.localizations.containsKey(localeCode) ?? false;
      final cachedBody = DocumentStorage.cachedBody(documentId, localeCode);

      final String body;
      if (oldLocaleExists && cachedBody != null) {
        body = cachedBody;
      } else {
        final bodyPath = readRemoteRequiredString(localization, "bodyPath");
        final bodyUri = endpoint.resolvePayloadUri(bodyPath);
        body = await _fetchText(bodyUri, cachedBody: cachedBody);
      }
      localizations[localeCode] = DocumentLocalization(title: title, summary: summary);
      cachedBodies[cacheKey] = body;
    }
    return (localizations: localizations, cachedBodies: cachedBodies);
  }

  Future<String> _fetchText(Uri uri, {String? cachedBody}) async {
    final result = await getRemoteUri<String>(_dio, uri);
    if (result.notModified) {
      if (cachedBody != null) {
        return cachedBody;
      }
      warning(
        "Remote document body returned 304 but no cached body available for $uri."
        " The ETag may be stale; clearing and retrying.",
      );
      EtagCache.remove(uri);
      final retry = await getRemoteUri<String>(_dio, uri);
      return retry.response.data ?? "";
    }
    return result.response.data ?? "";
  }
}

String _normalizeLocaleCode(String value) {
  final normalized = value.trim().toLowerCase().replaceAll("-", "_");
  if (normalized.isEmpty || normalized.contains("/") || normalized.contains("..")) {
    throw RemoteContentException("Invalid remote document locale: $value");
  }
  return normalized;
}

void _validateDocumentId(String id) {
  if (id.isEmpty ||
      id.contains("/") ||
      id.contains("..") ||
      Uri.decodeComponent(id).contains("..")) {
    throw RemoteContentException("Invalid remote document id: $id");
  }
}
