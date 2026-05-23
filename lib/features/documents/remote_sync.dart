import "dart:async";
import "dart:convert";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/documents/models.dart";
import "package:eve_fit_assistant/features/documents/repository.dart";
import "package:eve_fit_assistant/features/documents/storage.dart";
import "package:eve_fit_assistant/features/remote_content/endpoint.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

const Set<String> _supportedKinds = <String>{"announcement", "information", "version"};

final remoteDocumentSyncServiceProvider = Provider<RemoteDocumentSyncService>(
  (Ref ref) => RemoteDocumentSyncService(ref: ref),
);

class RemoteDocumentSyncService {
  RemoteDocumentSyncService({required Ref ref, Dio? dio}) : _ref = ref, _dio = dio ?? Dio();

  final Ref _ref;
  final Dio _dio;

  Future<bool> sync() async {
    final config = _ref.read(appSettingServiceProvider).remoteContent;
    if (!config.enabled) {
      return false;
    }

    try {
      final endpoint = RemoteContentEndpoint.fromSetting(config);
      final index = await _fetchJson(endpoint.indexUri);
      final documentCatalogPath = _readDocumentCatalogPath(index, endpoint.channel);
      if (documentCatalogPath == null) {
        return false;
      }

      final catalogUri = endpoint.resolvePayloadUri(documentCatalogPath);
      final catalogPayload = await _fetchJson(catalogUri);
      final parsedCatalog = await _parseCatalog(catalogPayload, endpoint);
      DocumentStorage.replaceRemoteCatalog(parsedCatalog.catalog, parsedCatalog.cachedBodies);
      _ref.invalidate(documentFeedProvider);
      info("Synced ${parsedCatalog.catalog.entries.length} remote document entries.");
      return true;
    } on Object catch (exception, stackTrace) {
      warning("Remote document sync failed: $exception", stackTrace: stackTrace);
      return false;
    }
  }

  Future<Map<String, dynamic>> _fetchJson(Uri uri) async {
    final response = await _getUri<Object>(uri);
    final data = response.data;
    final Object? decoded = switch (data) {
      final String text => jsonDecode(text),
      final Map<String, dynamic> map => map,
      _ => throw RemoteContentException("Remote JSON response is not an object: $uri"),
    };
    if (decoded is! Map<String, dynamic>) {
      throw RemoteContentException("Remote JSON response is not an object: $uri");
    }
    return decoded;
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

    final entries = <DocumentEntry>[];
    final cachedBodies = <String, String>{};
    final seenIds = <String>{};

    for (final rawEntry in rawEntries) {
      if (rawEntry is! Map<String, dynamic>) {
        throw const RemoteContentException("Remote document entry must be an object.");
      }
      final parsedEntry = await _parseEntry(rawEntry, endpoint);
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
    RemoteContentEndpoint endpoint,
  ) async {
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
    final localizations = await _parseLocalizations(payload, endpoint, id);

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
    String documentId,
  ) async {
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
      final bodyPath = readRemoteRequiredString(localization, "bodyPath");
      final bodyUri = endpoint.resolvePayloadUri(bodyPath);
      final body = await _fetchText(bodyUri);
      localizations[localeCode] = DocumentLocalization(title: title, summary: summary);
      cachedBodies[DocumentStorage.cacheKey(documentId, localeCode)] = body;
    }
    return (localizations: localizations, cachedBodies: cachedBodies);
  }

  Future<String> _fetchText(Uri uri) async {
    final response = await _getUri<String>(uri);
    return response.data ?? "";
  }

  Future<Response<T>> _getUri<T>(Uri uri) async {
    try {
      return await _dio.getUri<T>(uri, options: Options(responseType: ResponseType.plain));
    } on DioException catch (exception) {
      final response = exception.response;
      final status = response?.statusCode;
      final body = response?.data?.toString();
      final bodySnippet = body == null || body.length <= 300 ? body : body.substring(0, 300);
      throw RemoteContentException(
        "Remote request failed for $uri"
        "${status == null ? "" : " with HTTP $status"}"
        "${bodySnippet == null || bodySnippet.isEmpty ? "" : ": $bodySnippet"}",
      );
    }
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
