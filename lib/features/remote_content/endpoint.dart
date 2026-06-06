import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";

const int remoteContentClientApiVersion = 1;
const int remoteContentSchemaVersion = 1;
const String supportedRemoteContentResourceRoot = "efa/v1/";

class RemoteContentEndpoint {
  RemoteContentEndpoint._({
    required this.originUri,
    required this.resourceRoot,
    required this.channel,
  });

  factory RemoteContentEndpoint.fromSetting(RemoteContentSetting setting) {
    final originUrl = setting.originUrl.trim();
    if (originUrl.isEmpty) {
      throw const RemoteContentException("Remote origin URL must not be empty.");
    }
    final originUri = Uri.tryParse(originUrl);
    if (originUri == null || !originUri.hasScheme || originUri.host.isEmpty) {
      throw RemoteContentException("Remote origin URL is invalid: $originUrl");
    }
    if (originUri.scheme != "http" && originUri.scheme != "https") {
      throw RemoteContentException("Remote origin URL must use HTTP or HTTPS: $originUrl");
    }
    final resourceRoot = normalizeRemoteResourceRoot(setting.resourceRoot);
    if (resourceRoot != supportedRemoteContentResourceRoot) {
      throw RemoteContentException(
        "Unsupported remote resource root '$resourceRoot'; "
        "expected '$supportedRemoteContentResourceRoot'.",
      );
    }
    return RemoteContentEndpoint._(
      originUri: originUri,
      resourceRoot: resourceRoot,
      channel: validateRemoteChannel(setting.channel),
    );
  }

  final Uri originUri;
  final String resourceRoot;
  final String channel;

  Uri get indexUri => resolvePayloadUri("channels/$channel/index.json");

  Uri resolvePayloadUri(String relativePath) {
    final normalizedPath = validateRemoteRelativePayloadPath(relativePath);
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

class RemoteContentException implements Exception {
  const RemoteContentException(this.message);

  final String message;

  @override
  String toString() => message;
}

String normalizeRemoteResourceRoot(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty ||
      normalized.startsWith("/") ||
      Uri.tryParse(normalized)?.hasScheme == true) {
    throw RemoteContentException("Invalid remote resource root: $value");
  }
  final parts = normalized.split("/").where((part) => part.isNotEmpty).toList(growable: false);
  if (parts.any((part) => part == ".." || Uri.decodeComponent(part).contains(".."))) {
    throw RemoteContentException("Invalid remote resource root: $value");
  }
  return "${parts.join("/")}/";
}

String validateRemoteChannel(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.contains("/") || normalized.contains("..")) {
    throw RemoteContentException("Invalid remote channel: $value");
  }
  if (Uri.decodeComponent(normalized).contains("..")) {
    throw RemoteContentException("Invalid remote channel: $value");
  }
  final channel = Channel.tryParse(normalized);
  if (channel == null) {
    throw RemoteContentException(
      "Unknown remote channel: '$value'. "
      "Expected one of: ${Channel.values.map((c) => c.value).join(", ")}.",
    );
  }
  return normalized;
}

String validateRemoteRelativePayloadPath(String value) {
  final normalized = value.trim();
  final parsed = Uri.tryParse(normalized);
  if (normalized.isEmpty ||
      normalized.startsWith("/") ||
      parsed == null ||
      parsed.hasScheme ||
      parsed.hasAuthority) {
    throw RemoteContentException("Invalid remote relative path: $value");
  }
  final parts = normalized.split("/");
  if (parts.any((part) => part.isEmpty || part == "." || part == "..")) {
    throw RemoteContentException("Invalid remote relative path: $value");
  }
  if (parts.any((part) => Uri.decodeComponent(part).contains(".."))) {
    throw RemoteContentException("Invalid remote relative path: $value");
  }
  return parts.join("/");
}

void expectRemoteInt(Map<String, dynamic> payload, String key, int expected) {
  final value = readRemoteRequiredInt(payload, key);
  if (value != expected) {
    throw RemoteContentException("Expected $key=$expected, got $value.");
  }
}

int readRemoteRequiredInt(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value is! int) {
    throw RemoteContentException("Remote field '$key' must be an integer.");
  }
  return value;
}

String readRemoteRequiredString(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value is! String || value.trim().isEmpty) {
    throw RemoteContentException("Remote field '$key' must be a non-empty string.");
  }
  return value;
}

String? readRemoteOptionalString(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw RemoteContentException("Remote field '$key' must be a string when set.");
  }
  return value;
}

bool readRemoteOptionalBool(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value == null) {
    return false;
  }
  if (value is! bool) {
    throw RemoteContentException("Remote field '$key' must be a boolean when set.");
  }
  return value;
}

List<String> readRemoteOptionalStringList(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value == null) {
    return const <String>[];
  }
  if (value is! List<Object?> || value.any((item) => item is! String)) {
    throw RemoteContentException("Remote field '$key' must be a string list when set.");
  }
  return value.cast<String>();
}

int readRemoteOptionalInt(Map<String, dynamic> payload, String key, int defaultValue) {
  final value = payload[key];
  if (value == null) {
    return defaultValue;
  }
  if (value is! int) {
    throw RemoteContentException("Remote field '$key' must be an integer when set.");
  }
  return value;
}

IList<int> readRemoteOptionalIntList(
  Map<String, dynamic> payload,
  String key,
  IList<int> defaultValue,
) {
  final value = payload[key];
  if (value == null) {
    return defaultValue;
  }
  if (value is! List<Object?> || value.any((item) => item is! int)) {
    throw RemoteContentException("Remote field '$key' must be an int list when set.");
  }
  return value.cast<int>().toIList();
}
