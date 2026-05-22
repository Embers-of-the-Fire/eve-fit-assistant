import "dart:async";
import "dart:convert";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/documents/models.dart";
import "package:eve_fit_assistant/features/documents/repository.dart";
import "package:eve_fit_assistant/features/documents/storage.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

const int _clientApiVersion = 1;
const int _schemaVersion = 1;
const String _supportedResourceRoot = "efa/v1/";
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
      final endpoint = _RemoteEndpoint.fromSetting(config);
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
    final response = await _dio.getUri<Object>(
      uri,
      options: Options(responseType: ResponseType.plain),
    );
    final data = response.data;
    final Object? decoded = switch (data) {
      final String text => jsonDecode(text),
      final Map<String, dynamic> map => map,
      _ => throw RemoteDocumentSyncException("Remote JSON response is not an object: $uri"),
    };
    if (decoded is! Map<String, dynamic>) {
      throw RemoteDocumentSyncException("Remote JSON response is not an object: $uri");
    }
    return decoded;
  }

  String? _readDocumentCatalogPath(Map<String, dynamic> index, String expectedChannel) {
    _expectInt(index, "schemaVersion", _schemaVersion);
    final minClientApi = _readRequiredInt(index, "minClientApi");
    if (minClientApi > _clientApiVersion) {
      throw RemoteDocumentSyncException(
        "Remote index requires API $minClientApi, client supports $_clientApiVersion.",
      );
    }
    final channel = _readRequiredString(index, "channel");
    if (channel != expectedChannel) {
      throw RemoteDocumentSyncException(
        "Remote index channel '$channel' does not match '$expectedChannel'.",
      );
    }
    final documents = index["documents"];
    if (documents == null) {
      return null;
    }
    if (documents is! Map<String, dynamic>) {
      throw const RemoteDocumentSyncException("Remote index documents section is invalid.");
    }
    return _readRequiredString(documents, "catalogPath");
  }

  Future<({DocumentCatalog catalog, Map<String, String> cachedBodies})> _parseCatalog(
    Map<String, dynamic> payload,
    _RemoteEndpoint endpoint,
  ) async {
    _expectInt(payload, "schemaVersion", _schemaVersion);
    final catalogVersion = _readRequiredInt(payload, "version");
    final rawEntries = payload["entries"];
    if (rawEntries is! List<Object?>) {
      throw const RemoteDocumentSyncException("Remote document catalog entries must be a list.");
    }

    final entries = <DocumentEntry>[];
    final cachedBodies = <String, String>{};
    final seenIds = <String>{};

    for (final rawEntry in rawEntries) {
      if (rawEntry is! Map<String, dynamic>) {
        throw const RemoteDocumentSyncException("Remote document entry must be an object.");
      }
      final parsedEntry = await _parseEntry(rawEntry, endpoint);
      if (!seenIds.add(parsedEntry.entry.id)) {
        throw RemoteDocumentSyncException("Duplicate remote document id: ${parsedEntry.entry.id}");
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
    _RemoteEndpoint endpoint,
  ) async {
    final id = _readRequiredString(payload, "id");
    _validateDocumentId(id);
    final kind = _readRequiredString(payload, "kind");
    if (!_supportedKinds.contains(kind)) {
      throw RemoteDocumentSyncException("Unsupported remote document kind '$kind' for '$id'.");
    }
    final source = _readRequiredString(payload, "source");
    if (source != "remote") {
      throw RemoteDocumentSyncException("Remote document '$id' must use source 'remote'.");
    }
    final publishedAt = DateTime.tryParse(_readRequiredString(payload, "publishedAt"));
    if (publishedAt == null) {
      throw RemoteDocumentSyncException("Remote document '$id' has invalid publishedAt.");
    }
    final localizations = await _parseLocalizations(payload, endpoint, id);

    return (
      entry: DocumentEntry(
        id: id,
        kind: DocumentEntryKind.values.byName(kind),
        source: DocumentEntrySource.remote,
        publishedAt: publishedAt,
        localizations: localizations.localizations,
        tags: _readOptionalStringList(payload, "tags"),
        startup: _readOptionalBool(payload, "startup"),
        minAppVer: _readOptionalString(payload, "minAppVer"),
        appVer: _readOptionalString(payload, "appVer"),
      ),
      cachedBodies: localizations.cachedBodies,
    );
  }

  Future<({Map<String, DocumentLocalization> localizations, Map<String, String> cachedBodies})>
  _parseLocalizations(
    Map<String, dynamic> payload,
    _RemoteEndpoint endpoint,
    String documentId,
  ) async {
    final rawLocalizations = payload["localizations"];
    if (rawLocalizations is! Map<String, dynamic> || rawLocalizations.isEmpty) {
      throw RemoteDocumentSyncException("Remote document '$documentId' has no localizations.");
    }

    final localizations = <String, DocumentLocalization>{};
    final cachedBodies = <String, String>{};
    for (final MapEntry<String, dynamic> item in rawLocalizations.entries) {
      final localeCode = _normalizeLocaleCode(item.key);
      if (item.value is! Map<String, dynamic>) {
        throw RemoteDocumentSyncException(
          "Remote document '$documentId' localization '$localeCode' is invalid.",
        );
      }
      final localization = item.value as Map<String, dynamic>;
      final title = _readRequiredString(localization, "title");
      final summary = _readRequiredString(localization, "summary");
      final bodyPath = _readRequiredString(localization, "bodyPath");
      final bodyUri = endpoint.resolvePayloadUri(bodyPath);
      final body = await _fetchText(bodyUri);
      localizations[localeCode] = DocumentLocalization(title: title, summary: summary);
      cachedBodies[DocumentStorage.cacheKey(documentId, localeCode)] = body;
    }
    return (localizations: localizations, cachedBodies: cachedBodies);
  }

  Future<String> _fetchText(Uri uri) async {
    final response = await _dio.getUri<String>(
      uri,
      options: Options(responseType: ResponseType.plain),
    );
    return response.data ?? "";
  }
}

class _RemoteEndpoint {
  _RemoteEndpoint._({required this.originUri, required this.resourceRoot, required this.channel});

  factory _RemoteEndpoint.fromSetting(RemoteContentSetting setting) {
    final originUrl = setting.originUrl.trim();
    if (originUrl.isEmpty) {
      throw const RemoteDocumentSyncException("Remote origin URL must not be empty.");
    }
    final originUri = Uri.tryParse(originUrl);
    if (originUri == null || !originUri.hasScheme || originUri.host.isEmpty) {
      throw RemoteDocumentSyncException("Remote origin URL is invalid: $originUrl");
    }
    if (originUri.scheme != "http" && originUri.scheme != "https") {
      throw RemoteDocumentSyncException("Remote origin URL must use HTTP or HTTPS: $originUrl");
    }
    final resourceRoot = _normalizeResourceRoot(setting.resourceRoot);
    if (resourceRoot != _supportedResourceRoot) {
      throw RemoteDocumentSyncException(
        "Unsupported remote resource root '$resourceRoot'; expected '$_supportedResourceRoot'.",
      );
    }
    final channel = _validateChannel(setting.channel);
    return _RemoteEndpoint._(originUri: originUri, resourceRoot: resourceRoot, channel: channel);
  }

  final Uri originUri;
  final String resourceRoot;
  final String channel;

  Uri get indexUri => resolvePayloadUri("channels/$channel/index.json");

  Uri resolvePayloadUri(String relativePath) {
    final normalizedPath = _validateRelativePayloadPath(relativePath);
    final originPath = originUri.path.endsWith("/") ? originUri.path : "${originUri.path}/";
    final path = Uri(
      pathSegments: <String>[
        ...originPath.split("/").where((segment) => segment.isNotEmpty),
        ...resourceRoot.split("/").where((segment) => segment.isNotEmpty),
        ...normalizedPath.split("/"),
      ],
    ).path;
    return originUri.replace(path: path);
  }
}

class RemoteDocumentSyncException implements Exception {
  const RemoteDocumentSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _normalizeResourceRoot(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty ||
      normalized.startsWith("/") ||
      Uri.tryParse(normalized)?.hasScheme == true) {
    throw RemoteDocumentSyncException("Invalid remote resource root: $value");
  }
  final parts = normalized.split("/").where((part) => part.isNotEmpty).toList(growable: false);
  if (parts.any((part) => part == ".." || Uri.decodeComponent(part).contains(".."))) {
    throw RemoteDocumentSyncException("Invalid remote resource root: $value");
  }
  return "${parts.join("/")}/";
}

String _validateChannel(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.contains("/") || normalized.contains("..")) {
    throw RemoteDocumentSyncException("Invalid remote channel: $value");
  }
  if (Uri.decodeComponent(normalized).contains("..")) {
    throw RemoteDocumentSyncException("Invalid remote channel: $value");
  }
  return normalized;
}

String _validateRelativePayloadPath(String value) {
  final normalized = value.trim();
  final parsed = Uri.tryParse(normalized);
  if (normalized.isEmpty ||
      normalized.startsWith("/") ||
      parsed == null ||
      parsed.hasScheme ||
      parsed.hasAuthority) {
    throw RemoteDocumentSyncException("Invalid remote relative path: $value");
  }
  final parts = normalized.split("/");
  if (parts.any((part) => part.isEmpty || part == "." || part == "..")) {
    throw RemoteDocumentSyncException("Invalid remote relative path: $value");
  }
  if (parts.any((part) => Uri.decodeComponent(part).contains(".."))) {
    throw RemoteDocumentSyncException("Invalid remote relative path: $value");
  }
  return parts.join("/");
}

String _normalizeLocaleCode(String value) {
  final normalized = value.trim().toLowerCase().replaceAll("-", "_");
  if (normalized.isEmpty || normalized.contains("/") || normalized.contains("..")) {
    throw RemoteDocumentSyncException("Invalid remote document locale: $value");
  }
  return normalized;
}

void _validateDocumentId(String id) {
  if (id.isEmpty ||
      id.contains("/") ||
      id.contains("..") ||
      Uri.decodeComponent(id).contains("..")) {
    throw RemoteDocumentSyncException("Invalid remote document id: $id");
  }
}

void _expectInt(Map<String, dynamic> payload, String key, int expected) {
  final value = _readRequiredInt(payload, key);
  if (value != expected) {
    throw RemoteDocumentSyncException("Expected $key=$expected, got $value.");
  }
}

int _readRequiredInt(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value is! int) {
    throw RemoteDocumentSyncException("Remote field '$key' must be an integer.");
  }
  return value;
}

String _readRequiredString(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value is! String || value.trim().isEmpty) {
    throw RemoteDocumentSyncException("Remote field '$key' must be a non-empty string.");
  }
  return value;
}

String? _readOptionalString(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw RemoteDocumentSyncException("Remote field '$key' must be a string when set.");
  }
  return value;
}

bool _readOptionalBool(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value == null) {
    return false;
  }
  if (value is! bool) {
    throw RemoteDocumentSyncException("Remote field '$key' must be a boolean when set.");
  }
  return value;
}

List<String> _readOptionalStringList(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value == null) {
    return const <String>[];
  }
  if (value is! List<Object?> || value.any((item) => item is! String)) {
    throw RemoteDocumentSyncException("Remote field '$key' must be a string list when set.");
  }
  return value.cast<String>();
}
