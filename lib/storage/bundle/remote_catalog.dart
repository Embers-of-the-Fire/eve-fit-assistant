import "dart:convert";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/remote_content/endpoint.dart";
import "package:eve_fit_assistant/storage/bundle/manager.dart";
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/services.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "remote_catalog.freezed.dart";
part "remote_catalog.g.dart";

const String _packageVersionAsset = "pubspec.yaml";

enum RemoteBundleArtifactVariant { full, incremental }

@freezed
abstract class RemoteBundleArtifact with _$RemoteBundleArtifact {
  const factory RemoteBundleArtifact({
    required String artifactId,
    required String bundleId,
    required RemoteBundleArtifactVariant variant,
    required String appVersion,
    required String gameVersion,
    required String gameBuild,
    required String gameRegion,
    required String gameBranch,
    required String gameServer,
    required DateTime generatedAt,
    required String artifactPath,
    required int artifactSize,
    required String artifactSha256,
    required String manifestPath,
    required String manifestHash,
    String? baseBundleId,
    String? baseManifestHash,
  }) = _RemoteBundleArtifact;

  factory RemoteBundleArtifact.fromJson(Map<String, dynamic> json) {
    final generatedAt = DateTime.tryParse(readRemoteRequiredString(json, "generatedAt"));
    if (generatedAt == null) {
      throw RemoteContentException(
        "Remote bundle artifact '${json["artifactId"]}' has invalid generatedAt.",
      );
    }
    return RemoteBundleArtifact(
      artifactId: readRemoteRequiredString(json, "artifactId"),
      bundleId: readRemoteRequiredString(json, "bundleId"),
      variant: _readVariant(json),
      appVersion: readRemoteRequiredString(json, "appVersion"),
      gameVersion: readRemoteRequiredString(json, "gameVersion"),
      gameBuild: readRemoteRequiredString(json, "gameBuild"),
      gameRegion: readRemoteRequiredString(json, "gameRegion"),
      gameBranch: readRemoteRequiredString(json, "gameBranch"),
      gameServer: readRemoteRequiredString(json, "gameServer"),
      generatedAt: generatedAt,
      artifactPath: readRemoteRequiredString(json, "artifactPath"),
      artifactSize: readRemoteRequiredInt(json, "artifactSize"),
      artifactSha256: readRemoteRequiredString(json, "artifactSha256"),
      manifestPath: readRemoteRequiredString(json, "manifestPath"),
      manifestHash: readRemoteRequiredString(json, "manifestHash"),
      baseBundleId: readRemoteOptionalString(json, "baseBundleId"),
      baseManifestHash: readRemoteOptionalString(json, "baseManifestHash"),
    );
  }

  const RemoteBundleArtifact._();

  bool get isFull => variant == RemoteBundleArtifactVariant.full;
  bool get isIncremental => variant == RemoteBundleArtifactVariant.incremental;

  static RemoteBundleArtifactVariant _readVariant(Map<String, dynamic> json) {
    final value = readRemoteRequiredString(json, "variant");
    return switch (value) {
      "full" => RemoteBundleArtifactVariant.full,
      "incremental" => RemoteBundleArtifactVariant.incremental,
      _ => throw RemoteContentException("Unsupported remote bundle artifact variant: $value"),
    };
  }
}

@freezed
abstract class RemoteBundleCatalog with _$RemoteBundleCatalog {
  const factory RemoteBundleCatalog({required IList<RemoteBundleArtifact> artifacts}) =
      _RemoteBundleCatalog;

  factory RemoteBundleCatalog.fromJson(Map<String, dynamic> json) {
    expectRemoteInt(json, "schemaVersion", remoteContentSchemaVersion);
    final artifacts = json["artifacts"];
    if (artifacts is! List<Object?>) {
      throw const RemoteContentException("Remote bundle catalog artifacts must be a list.");
    }
    return RemoteBundleCatalog(
      artifacts: artifacts.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const RemoteContentException("Remote bundle artifact must be an object.");
        }
        return RemoteBundleArtifact.fromJson(item);
      }).toIList(),
    );
  }
}

@freezed
abstract class RemoteBundleCatalogState with _$RemoteBundleCatalogState {
  const factory RemoteBundleCatalogState({
    @Default(false) bool enabled,
    @Default(false) bool loaded,
    @Default(IList<RemoteBundleArtifact>.empty()) IList<RemoteBundleArtifact> compatible,
    String? error,
  }) = _RemoteBundleCatalogState;

  const RemoteBundleCatalogState._();

  bool get hasCompatibleArtifacts => compatible.isNotEmpty;
}

@riverpod
class RemoteBundleCatalogManager extends _$RemoteBundleCatalogManager {
  RemoteBundleCatalogManager({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<RemoteBundleCatalogState> build() async => refresh();

  Future<RemoteBundleCatalogState> refresh() async {
    final config = ref.read(appSettingServiceProvider).remoteContent;
    if (!config.enabled) {
      return const RemoteBundleCatalogState();
    }

    try {
      final endpoint = RemoteContentEndpoint.fromSetting(config);
      final index = await _fetchJson(endpoint.indexUri);
      final catalogPath = _readBundleCatalogPath(index, endpoint.channel);
      if (catalogPath == null) {
        return const RemoteBundleCatalogState(enabled: true, loaded: true);
      }

      final catalog = RemoteBundleCatalog.fromJson(
        await _fetchJson(endpoint.resolvePayloadUri(catalogPath)),
      );
      final appVersion = await _readAppVersion();
      final compatible = _selectCompatibleArtifacts(
        catalog.artifacts,
        endpoint: endpoint,
        appVersion: appVersion,
      );
      info("Discovered ${compatible.length} compatible remote bundle artifacts.");
      return RemoteBundleCatalogState(enabled: true, loaded: true, compatible: compatible);
    } on Object catch (exception, stackTrace) {
      warning("Remote bundle catalog sync failed: $exception", stackTrace: stackTrace);
      return RemoteBundleCatalogState(enabled: true, loaded: true, error: exception.toString());
    }
  }

  String? _readBundleCatalogPath(Map<String, dynamic> index, String expectedChannel) {
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
    final bundles = index["bundles"];
    if (bundles == null) {
      return null;
    }
    if (bundles is! Map<String, dynamic>) {
      throw const RemoteContentException("Remote index bundles section is invalid.");
    }
    return readRemoteRequiredString(bundles, "catalogPath");
  }

  IList<RemoteBundleArtifact> _selectCompatibleArtifacts(
    IList<RemoteBundleArtifact> artifacts, {
    required RemoteContentEndpoint endpoint,
    required String appVersion,
  }) {
    final registry = ref.read(bundleRegistryManagerProvider);
    final installedRegistrars = <String, BundleRegistrar>{};
    for (final bundleId in registry.bundles.keys) {
      try {
        installedRegistrars[bundleId] = BundleRegistryManager.getRegistrar(bundleId);
      } on Object catch (exception) {
        warning("Skipping installed bundle $bundleId during remote matching: $exception");
      }
    }

    final compatible =
        artifacts
            .where((artifact) => _artifactMatchesEnvironment(artifact, endpoint, appVersion))
            .where((artifact) => _artifactMatchesInstalledState(artifact, installedRegistrars))
            .toList(growable: false)
          ..sort((a, b) {
            final variantOrder = _variantSortOrder(a).compareTo(_variantSortOrder(b));
            if (variantOrder != 0) {
              return variantOrder;
            }
            return b.generatedAt.compareTo(a.generatedAt);
          });
    return compatible.lock;
  }

  bool _artifactMatchesEnvironment(
    RemoteBundleArtifact artifact,
    RemoteContentEndpoint endpoint,
    String appVersion,
  ) => artifact.appVersion == appVersion && artifact.gameRegion == endpoint.region;

  bool _artifactMatchesInstalledState(
    RemoteBundleArtifact artifact,
    Map<String, BundleRegistrar> installedRegistrars,
  ) {
    if (artifact.isFull) {
      return true;
    }
    final baseBundleId = artifact.baseBundleId;
    final baseManifestHash = artifact.baseManifestHash;
    if (baseBundleId == null || baseManifestHash == null) {
      return false;
    }
    final registrar = installedRegistrars[baseBundleId];
    return registrar?.latest.manifestHash == baseManifestHash;
  }

  int _variantSortOrder(RemoteBundleArtifact artifact) => artifact.isIncremental ? 0 : 1;

  Future<Map<String, dynamic>> _fetchJson(Uri uri) async {
    final response = await _getUri<Object>(uri, ResponseType.plain);
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

  Future<Response<T>> _getUri<T>(Uri uri, ResponseType responseType) async {
    try {
      return await _dio.getUri<T>(uri, options: Options(responseType: responseType));
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

  Future<String> _readAppVersion() async {
    final pubspec = await rootBundle.loadString(_packageVersionAsset);
    for (final line in const LineSplitter().convert(pubspec)) {
      final trimmed = line.trim();
      if (trimmed.startsWith("version:")) {
        return trimmed.substring("version:".length).trim();
      }
    }
    throw const RemoteContentException("Unable to read app version from pubspec.yaml.");
  }
}
