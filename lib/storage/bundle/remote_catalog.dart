import "dart:convert";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";
import "package:eve_fit_assistant/features/remote_content/endpoint.dart";
import "package:eve_fit_assistant/features/remote_content/http.dart";
import "package:eve_fit_assistant/storage/bundle/manager.dart";
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/services.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";
import "package:yaml/yaml.dart";

part "remote_catalog.freezed.dart";
part "remote_catalog.g.dart";

const String _packageVersionAsset = "pubspec.yaml";

enum RemoteBundleArtifactVariant { full, incremental }

enum RemoteBundleCandidateState { recommended, available, installed, unavailable }

enum RemoteBundleCandidateRecommendation { incrementalUpdate, fullInstall, fullReplacement }

enum RemoteBundleCandidateUnavailableReason {
  appVersionMismatch,
  missingIncrementalMetadata,
  baseBundleNotInstalled,
  installedManifestMissing,
  baseManifestMismatch,
}

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
abstract class RemoteBundleCandidate with _$RemoteBundleCandidate {
  const factory RemoteBundleCandidate({
    required RemoteBundleArtifact artifact,
    required RemoteBundleCandidateState state,
    RemoteBundleCandidateRecommendation? recommendation,
    RemoteBundleCandidateUnavailableReason? unavailableReason,
    String? installedManifestHash,
  }) = _RemoteBundleCandidate;

  const RemoteBundleCandidate._();

  bool get canImport =>
      state == RemoteBundleCandidateState.recommended ||
      state == RemoteBundleCandidateState.available;
}

@freezed
abstract class RemoteBundleCatalogState with _$RemoteBundleCatalogState {
  const factory RemoteBundleCatalogState({
    @Default(false) bool enabled,
    @Default(false) bool loaded,
    @Default(false) bool catalogAvailable,
    String? appVersion,
    @Default(IList<RemoteBundleCandidate>.empty()) IList<RemoteBundleCandidate> candidates,
    String? error,
  }) = _RemoteBundleCatalogState;

  const RemoteBundleCatalogState._();

  IList<RemoteBundleCandidate> get recommended => candidates
      .where((candidate) => candidate.state == RemoteBundleCandidateState.recommended)
      .toIList();

  IList<RemoteBundleCandidate> get available => candidates
      .where((candidate) => candidate.state == RemoteBundleCandidateState.available)
      .toIList();

  IList<RemoteBundleCandidate> get installed => candidates
      .where((candidate) => candidate.state == RemoteBundleCandidateState.installed)
      .toIList();

  IList<RemoteBundleCandidate> get unavailable => candidates
      .where((candidate) => candidate.state == RemoteBundleCandidateState.unavailable)
      .toIList();

  IList<RemoteBundleCandidate> get importable =>
      candidates.where((candidate) => candidate.canImport).toIList();

  IList<RemoteBundleArtifact> get compatible =>
      importable.map((candidate) => candidate.artifact).toIList();

  bool get hasCompatibleArtifacts => compatible.isNotEmpty;
}

@riverpod
class RemoteBundleCatalogManager extends _$RemoteBundleCatalogManager {
  RemoteBundleCatalogManager({Dio? dio}) : _dio = dio ?? createRemoteDio();

  final Dio _dio;
  String? _lastBundleRevision;

  @override
  Future<RemoteBundleCatalogState> build() async => refresh();

  Future<RemoteBundleCatalogState> refresh() async {
    final config = ref.read(appSettingServiceProvider).remoteContent;
    if (!config.enabled) {
      return const RemoteBundleCatalogState();
    }

    try {
      final endpoint = RemoteContentEndpoint.fromSetting(config);

      final indexResult = await getRemoteUri<String>(_dio, endpoint.indexUri);
      if (indexResult.notModified) {
        info("Remote bundle index unchanged; skipping refresh.");
        final prev = state.asData?.value;
        return RemoteBundleCatalogState(
          enabled: true,
          loaded: true,
          catalogAvailable: true,
          appVersion: prev?.appVersion,
          candidates: prev?.candidates ?? const IList.empty(),
        );
      }
      final indexText = indexResult.response.data;
      if (indexText == null || indexText.isEmpty) {
        throw const RemoteContentException("Remote index response body is empty.");
      }
      final index = jsonDecode(indexText) as Map<String, dynamic>;
      final catalogPath = _readBundleCatalogPath(index, endpoint.channel);
      if (catalogPath == null) {
        return const RemoteBundleCatalogState(enabled: true, loaded: true);
      }

      final bundles = index["bundles"] as Map<String, dynamic>?;
      final bundleRevision = bundles?["revision"] as String?;
      if (bundleRevision != null && bundleRevision == _lastBundleRevision) {
        info("Remote bundle revision unchanged ($bundleRevision); skipping catalog fetch.");
        final prev = state.asData?.value;
        return RemoteBundleCatalogState(
          enabled: true,
          loaded: true,
          catalogAvailable: true,
          appVersion: prev?.appVersion,
          candidates: prev?.candidates ?? const IList.empty(),
        );
      }
      _lastBundleRevision = bundleRevision;

      final catalog = RemoteBundleCatalog.fromJson(
        await fetchRemoteJson(_dio, endpoint.resolvePayloadUri(catalogPath)),
      );
      final appVersion = await _readAppVersion();
      final candidates = _selectBundleCandidates(catalog.artifacts, appVersion: appVersion);
      info(
        "Discovered ${candidates.where((candidate) => candidate.canImport).length} "
        "compatible remote bundle artifacts.",
      );
      return RemoteBundleCatalogState(
        enabled: true,
        loaded: true,
        catalogAvailable: true,
        appVersion: appVersion,
        candidates: candidates,
      );
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

  IList<RemoteBundleCandidate> _selectBundleCandidates(
    IList<RemoteBundleArtifact> artifacts, {
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

    final candidates = [
      for (final artifact in artifacts)
        _candidateForArtifact(
          artifact,
          appVersion: appVersion,
          installedRegistrars: installedRegistrars,
        ),
    ];
    final recommendations = _recommendCandidates(candidates, installedRegistrars);
    final selected =
        candidates
            .map(
              (candidate) => recommendations.contains(candidate)
                  ? candidate.copyWith(
                      state: RemoteBundleCandidateState.recommended,
                      recommendation: _recommendationFor(candidate, installedRegistrars),
                    )
                  : candidate,
            )
            .toList(growable: false)
          ..sort(_compareCandidates);
    return selected.lock;
  }

  RemoteBundleCandidate _candidateForArtifact(
    RemoteBundleArtifact artifact, {
    required String appVersion,
    required Map<String, BundleRegistrar> installedRegistrars,
  }) {
    if (artifact.appVersion != appVersion) {
      return RemoteBundleCandidate(
        artifact: artifact,
        state: RemoteBundleCandidateState.unavailable,
        unavailableReason: RemoteBundleCandidateUnavailableReason.appVersionMismatch,
      );
    }

    final installedRegistrar = installedRegistrars[artifact.bundleId];
    final installedManifestHash = installedRegistrar?.latest.manifestHash;
    if (installedManifestHash == artifact.manifestHash) {
      return RemoteBundleCandidate(
        artifact: artifact,
        state: RemoteBundleCandidateState.installed,
        installedManifestHash: installedManifestHash,
      );
    }
    if (_registrarContainsManifest(installedRegistrar, artifact.manifestHash)) {
      return RemoteBundleCandidate(
        artifact: artifact,
        state: RemoteBundleCandidateState.installed,
        installedManifestHash: artifact.manifestHash,
      );
    }

    if (artifact.isFull) {
      return RemoteBundleCandidate(
        artifact: artifact,
        state: RemoteBundleCandidateState.available,
        installedManifestHash: installedManifestHash,
      );
    }

    final baseBundleId = artifact.baseBundleId;
    final baseManifestHash = artifact.baseManifestHash;
    if (baseBundleId == null || baseManifestHash == null) {
      return RemoteBundleCandidate(
        artifact: artifact,
        state: RemoteBundleCandidateState.unavailable,
        unavailableReason: RemoteBundleCandidateUnavailableReason.missingIncrementalMetadata,
      );
    }
    final registrar = installedRegistrars[baseBundleId];
    if (registrar == null) {
      return RemoteBundleCandidate(
        artifact: artifact,
        state: RemoteBundleCandidateState.unavailable,
        unavailableReason: RemoteBundleCandidateUnavailableReason.baseBundleNotInstalled,
      );
    }

    final baseInstalledManifestHash = registrar.latest.manifestHash;
    if (baseInstalledManifestHash == artifact.manifestHash) {
      return RemoteBundleCandidate(
        artifact: artifact,
        state: RemoteBundleCandidateState.installed,
        installedManifestHash: baseInstalledManifestHash,
      );
    }
    if (baseInstalledManifestHash == null) {
      return RemoteBundleCandidate(
        artifact: artifact,
        state: RemoteBundleCandidateState.unavailable,
        unavailableReason: RemoteBundleCandidateUnavailableReason.installedManifestMissing,
      );
    }
    if (baseInstalledManifestHash != baseManifestHash) {
      return RemoteBundleCandidate(
        artifact: artifact,
        state: RemoteBundleCandidateState.unavailable,
        unavailableReason: RemoteBundleCandidateUnavailableReason.baseManifestMismatch,
        installedManifestHash: baseInstalledManifestHash,
      );
    }

    return RemoteBundleCandidate(
      artifact: artifact,
      state: RemoteBundleCandidateState.available,
      installedManifestHash: baseInstalledManifestHash,
    );
  }

  bool _registrarContainsManifest(BundleRegistrar? registrar, String manifestHash) =>
      registrar?.history.any((patch) => patch.manifestHash == manifestHash) ?? false;

  Set<RemoteBundleCandidate> _recommendCandidates(
    List<RemoteBundleCandidate> candidates,
    Map<String, BundleRegistrar> installedRegistrars,
  ) {
    final hasInstalledBundles = installedRegistrars.isNotEmpty;
    final newestInstalledByBundleId = <String, RemoteBundleCandidate>{};
    for (final candidate in candidates.where(
      (candidate) => candidate.state == RemoteBundleCandidateState.installed,
    )) {
      final current = newestInstalledByBundleId[candidate.artifact.bundleId];
      if (current == null || candidate.artifact.generatedAt.isAfter(current.artifact.generatedAt)) {
        newestInstalledByBundleId[candidate.artifact.bundleId] = candidate;
      }
    }

    final byBundleId = <String, List<RemoteBundleCandidate>>{};
    for (final candidate in candidates.where((candidate) => candidate.canImport)) {
      if (hasInstalledBundles && !installedRegistrars.containsKey(candidate.artifact.bundleId)) {
        continue;
      }
      final newestInstalled = newestInstalledByBundleId[candidate.artifact.bundleId];
      if (newestInstalled != null &&
          !candidate.artifact.generatedAt.isAfter(newestInstalled.artifact.generatedAt)) {
        continue;
      }
      byBundleId.putIfAbsent(candidate.artifact.bundleId, () => []).add(candidate);
    }

    final recommendations = <RemoteBundleCandidate>{};
    for (final bundleCandidates in byBundleId.values) {
      bundleCandidates.sort(_compareImportableCandidates);
      recommendations.add(bundleCandidates.first);
    }
    return recommendations;
  }

  RemoteBundleCandidateRecommendation _recommendationFor(
    RemoteBundleCandidate candidate,
    Map<String, BundleRegistrar> installedRegistrars,
  ) {
    if (candidate.artifact.isIncremental) {
      return RemoteBundleCandidateRecommendation.incrementalUpdate;
    }
    if (installedRegistrars.containsKey(candidate.artifact.bundleId)) {
      return RemoteBundleCandidateRecommendation.fullReplacement;
    }
    return RemoteBundleCandidateRecommendation.fullInstall;
  }

  int _compareCandidates(RemoteBundleCandidate a, RemoteBundleCandidate b) {
    final stateOrder = _candidateStateSortOrder(a).compareTo(_candidateStateSortOrder(b));
    if (stateOrder != 0) {
      return stateOrder;
    }
    return _compareArtifacts(a.artifact, b.artifact);
  }

  int _compareImportableCandidates(RemoteBundleCandidate a, RemoteBundleCandidate b) =>
      _compareArtifacts(a.artifact, b.artifact);

  int _compareArtifacts(RemoteBundleArtifact a, RemoteBundleArtifact b) {
    final variantOrder = _variantSortOrder(a).compareTo(_variantSortOrder(b));
    if (variantOrder != 0) {
      return variantOrder;
    }
    final generatedOrder = b.generatedAt.compareTo(a.generatedAt);
    if (generatedOrder != 0) {
      return generatedOrder;
    }
    return a.artifactId.compareTo(b.artifactId);
  }

  int _candidateStateSortOrder(RemoteBundleCandidate candidate) => switch (candidate.state) {
    RemoteBundleCandidateState.recommended => 0,
    RemoteBundleCandidateState.available => 1,
    RemoteBundleCandidateState.installed => 2,
    RemoteBundleCandidateState.unavailable => 3,
  };

  int _variantSortOrder(RemoteBundleArtifact artifact) => artifact.isIncremental ? 0 : 1;

  Future<String> _readAppVersion() async {
    final pubspec = await rootBundle.loadString(_packageVersionAsset);
    final yaml = loadYaml(pubspec);
    if (yaml is YamlMap) {
      final version = yaml["version"];
      if (version is String && version.trim().isNotEmpty) {
        return version.trim();
      }
    }
    throw const RemoteContentException("Unable to read app version from pubspec.yaml.");
  }
}
