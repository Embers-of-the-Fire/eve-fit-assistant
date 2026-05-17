import "package:eve_fit_assistant/storage/bundle/manager.dart";
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/storage/bundle/service/paths.dart";
import "package:eve_fit_assistant/storage/character/manager.dart";
import "package:eve_fit_assistant/storage/character/schema.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "impact.g.dart";

enum BundleImpactTargetKind { switchBundle, incrementalImport }

enum BundleImpactReason {
  bundleIdMismatch,
  missingComparableRevision,
  manifestMismatch,
  generationMismatch,
  buildMismatch,
  appVersionMismatch,
  incrementalPatch,
}

class BundleImpactTarget {
  const BundleImpactTarget({
    required this.kind,
    required this.targetBundle,
    this.sourceBundle,
    this.incrementalPatchHasPayload = false,
  });

  final BundleImpactTargetKind kind;
  final BundleMetadata targetBundle;
  final BundleMetadata? sourceBundle;
  final bool incrementalPatchHasPayload;
}

class BundleImpactedFit {
  const BundleImpactedFit({required this.metadata, required this.reason});

  final FitMetadata metadata;
  final BundleImpactReason reason;
}

class BundleImpactedCharacter {
  const BundleImpactedCharacter({required this.metadata, required this.reason});

  final CharacterMetadata metadata;
  final BundleImpactReason reason;
}

class BundleImpactReport {
  const BundleImpactReport({
    required this.target,
    required this.fits,
    required this.characters,
    required this.bundleDataImpacted,
  });

  final BundleImpactTarget target;
  final IList<BundleImpactedFit> fits;
  final IList<BundleImpactedCharacter> characters;
  final bool bundleDataImpacted;

  int get totalImpactedEntries => fits.length + characters.length + (bundleDataImpacted ? 1 : 0);
  bool get hasImpact => totalImpactedEntries > 0;
}

@riverpod
BundleImpactReport bundleSwitchImpact(Ref ref, String bundleId) {
  final targetBundle = _bundleMetadataFromInstalledBundle(bundleId);
  return analyzeBundleImpact(
    fitRegistry: ref.watch(fitRegistryManagerProvider),
    characterRegistry: ref.watch(characterRegistryManagerProvider),
    target: BundleImpactTarget(
      kind: BundleImpactTargetKind.switchBundle,
      targetBundle: targetBundle,
      sourceBundle: ref.watch(currentBundleProvider),
    ),
  );
}

BundleImpactReport analyzeBundleImpact({
  required FitRegistry fitRegistry,
  required CharacterRegistry characterRegistry,
  required BundleImpactTarget target,
}) {
  final targetSnapshot = FitBundleSnapshot.fromBundleMetadata(target.targetBundle);
  final targetCharacterSnapshot = CharacterBundleSnapshot.fromBundleMetadata(target.targetBundle);
  final impactedFits = fitRegistry.fits.values
      .map((metadata) => (metadata, _fitImpactReason(metadata.bundleSnapshot, targetSnapshot)))
      .where((entry) => entry.$2 != null)
      .map((entry) => BundleImpactedFit(metadata: entry.$1, reason: entry.$2!))
      .toIList();
  final impactedCharacters = characterRegistry.characters.values
      .where((metadata) => !CharacterRegistryManager.isBuiltInCharacterId(metadata.characterId))
      .map(
        (metadata) =>
            (metadata, _characterImpactReason(metadata.bundleSnapshot, targetCharacterSnapshot)),
      )
      .where((entry) => entry.$2 != null)
      .map((entry) => BundleImpactedCharacter(metadata: entry.$1, reason: entry.$2!))
      .toIList();

  return BundleImpactReport(
    target: target,
    fits: impactedFits,
    characters: impactedCharacters,
    bundleDataImpacted:
        target.kind == BundleImpactTargetKind.incrementalImport &&
        target.incrementalPatchHasPayload,
  );
}

BundleMetadata bundleMetadataFromDescriptor({
  required BundleDescriptor descriptor,
  required BundleRegistrar registrar,
  required BundleServicePaths paths,
}) {
  final metadata = registrar.pushPatch(descriptor);
  return BundleMetadata(
    bundleId: descriptor.bundleId,
    paths: paths,
    lastModified: DateTime.now(),
    metadata: metadata,
  );
}

BundleMetadata _bundleMetadataFromInstalledBundle(String bundleId) {
  final registrar = BundleRegistryManager.getRegistrar(bundleId);
  return BundleMetadata(
    bundleId: bundleId,
    paths: BundleServicePaths(BundleManager.getBundlePath(bundleId)),
    lastModified: DateTime.now(),
    metadata: registrar,
  );
}

BundleImpactReason? _fitImpactReason(
  FitBundleSnapshot savedSnapshot,
  FitBundleSnapshot targetSnapshot,
) {
  if (savedSnapshot.bundleId != targetSnapshot.bundleId) {
    return BundleImpactReason.bundleIdMismatch;
  }
  if (!savedSnapshot.hasComparableRevision || !targetSnapshot.hasComparableRevision) {
    return BundleImpactReason.missingComparableRevision;
  }
  if (savedSnapshot.manifestHash case final savedManifestHash?) {
    final targetManifestHash = targetSnapshot.manifestHash;
    if (targetManifestHash != null && savedManifestHash != targetManifestHash) {
      return BundleImpactReason.manifestMismatch;
    }
  }
  if (savedSnapshot.generateTimestamp case final savedGenerateTimestamp?) {
    final targetGenerateTimestamp = targetSnapshot.generateTimestamp;
    if (targetGenerateTimestamp != null && savedGenerateTimestamp != targetGenerateTimestamp) {
      return BundleImpactReason.generationMismatch;
    }
  }
  if (savedSnapshot.gameBuild case final savedGameBuild?) {
    final targetGameBuild = targetSnapshot.gameBuild;
    if (targetGameBuild != null && savedGameBuild != targetGameBuild) {
      return BundleImpactReason.buildMismatch;
    }
  }
  if (savedSnapshot.appVersion case final savedAppVersion?) {
    final targetAppVersion = targetSnapshot.appVersion;
    if (targetAppVersion != null && savedAppVersion != targetAppVersion) {
      return BundleImpactReason.appVersionMismatch;
    }
  }
  return null;
}

BundleImpactReason? _characterImpactReason(
  CharacterBundleSnapshot savedSnapshot,
  CharacterBundleSnapshot targetSnapshot,
) {
  if (savedSnapshot.bundleId != targetSnapshot.bundleId) {
    return BundleImpactReason.bundleIdMismatch;
  }
  if (!savedSnapshot.hasComparableRevision || !targetSnapshot.hasComparableRevision) {
    return BundleImpactReason.missingComparableRevision;
  }
  if (savedSnapshot.manifestHash case final savedManifestHash?) {
    final targetManifestHash = targetSnapshot.manifestHash;
    if (targetManifestHash != null && savedManifestHash != targetManifestHash) {
      return BundleImpactReason.manifestMismatch;
    }
  }
  if (savedSnapshot.generateTimestamp case final savedGenerateTimestamp?) {
    final targetGenerateTimestamp = targetSnapshot.generateTimestamp;
    if (targetGenerateTimestamp != null && savedGenerateTimestamp != targetGenerateTimestamp) {
      return BundleImpactReason.generationMismatch;
    }
  }
  if (savedSnapshot.gameBuild case final savedGameBuild?) {
    final targetGameBuild = targetSnapshot.gameBuild;
    if (targetGameBuild != null && savedGameBuild != targetGameBuild) {
      return BundleImpactReason.buildMismatch;
    }
  }
  if (savedSnapshot.appVersion case final savedAppVersion?) {
    final targetAppVersion = targetSnapshot.appVersion;
    if (targetAppVersion != null && savedAppVersion != targetAppVersion) {
      return BundleImpactReason.appVersionMismatch;
    }
  }
  return null;
}
