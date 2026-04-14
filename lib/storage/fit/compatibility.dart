import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

enum FitBundleCompatibilityKind { compatible, outdated, incompatible, unavailable }

enum FitBundleCompatibilityReason {
  none,
  activeBundleUnavailable,
  bundleIdMismatch,
  missingComparableRevision,
  manifestMismatch,
  generationMismatch,
  buildMismatch,
  appVersionMismatch,
}

class FitBundleCompatibility {
  const FitBundleCompatibility({
    required this.kind,
    required this.reason,
    required this.savedSnapshot,
    required this.activeSnapshot,
  });

  const FitBundleCompatibility.compatible({
    required FitBundleSnapshot savedSnapshot,
    required FitBundleSnapshot activeSnapshot,
  }) : this(
         kind: FitBundleCompatibilityKind.compatible,
         reason: FitBundleCompatibilityReason.none,
         savedSnapshot: savedSnapshot,
         activeSnapshot: activeSnapshot,
       );

  final FitBundleCompatibilityKind kind;
  final FitBundleCompatibilityReason reason;
  final FitBundleSnapshot savedSnapshot;
  final FitBundleSnapshot? activeSnapshot;

  bool get allowsEditing => kind == FitBundleCompatibilityKind.compatible;
  bool get requiresAttention => kind != FitBundleCompatibilityKind.compatible;
}

FitBundleCompatibility evaluateFitBundleCompatibility(
  FitMetadata metadata,
  BundleMetadata? activeBundle,
) {
  final savedSnapshot = metadata.bundleSnapshot;
  if (activeBundle == null) {
    return FitBundleCompatibility(
      kind: FitBundleCompatibilityKind.unavailable,
      reason: FitBundleCompatibilityReason.activeBundleUnavailable,
      savedSnapshot: savedSnapshot,
      activeSnapshot: null,
    );
  }

  final activeSnapshot = FitBundleSnapshot.fromBundleMetadata(activeBundle);
  if (savedSnapshot.bundleId != activeSnapshot.bundleId) {
    return FitBundleCompatibility(
      kind: FitBundleCompatibilityKind.incompatible,
      reason: FitBundleCompatibilityReason.bundleIdMismatch,
      savedSnapshot: savedSnapshot,
      activeSnapshot: activeSnapshot,
    );
  }

  if (!savedSnapshot.hasComparableRevision) {
    return FitBundleCompatibility(
      kind: FitBundleCompatibilityKind.outdated,
      reason: FitBundleCompatibilityReason.missingComparableRevision,
      savedSnapshot: savedSnapshot,
      activeSnapshot: activeSnapshot,
    );
  }

  if (!activeSnapshot.hasComparableRevision) {
    return FitBundleCompatibility(
      kind: FitBundleCompatibilityKind.outdated,
      reason: FitBundleCompatibilityReason.missingComparableRevision,
      savedSnapshot: savedSnapshot,
      activeSnapshot: activeSnapshot,
    );
  }

  if (savedSnapshot.manifestHash case final savedManifestHash?) {
    final activeManifestHash = activeSnapshot.manifestHash;
    if (activeManifestHash != null && savedManifestHash != activeManifestHash) {
      return FitBundleCompatibility(
        kind: FitBundleCompatibilityKind.outdated,
        reason: FitBundleCompatibilityReason.manifestMismatch,
        savedSnapshot: savedSnapshot,
        activeSnapshot: activeSnapshot,
      );
    }
  }

  if (savedSnapshot.generateTimestamp case final savedGenerateTimestamp?) {
    final activeGenerateTimestamp = activeSnapshot.generateTimestamp;
    if (activeGenerateTimestamp != null && savedGenerateTimestamp != activeGenerateTimestamp) {
      return FitBundleCompatibility(
        kind: FitBundleCompatibilityKind.outdated,
        reason: FitBundleCompatibilityReason.generationMismatch,
        savedSnapshot: savedSnapshot,
        activeSnapshot: activeSnapshot,
      );
    }
  }

  if (savedSnapshot.gameBuild case final savedGameBuild?) {
    final activeGameBuild = activeSnapshot.gameBuild;
    if (activeGameBuild != null && savedGameBuild != activeGameBuild) {
      return FitBundleCompatibility(
        kind: FitBundleCompatibilityKind.outdated,
        reason: FitBundleCompatibilityReason.buildMismatch,
        savedSnapshot: savedSnapshot,
        activeSnapshot: activeSnapshot,
      );
    }
  }

  if (savedSnapshot.appVersion case final savedAppVersion?) {
    final activeAppVersion = activeSnapshot.appVersion;
    if (activeAppVersion != null && savedAppVersion != activeAppVersion) {
      return FitBundleCompatibility(
        kind: FitBundleCompatibilityKind.outdated,
        reason: FitBundleCompatibilityReason.appVersionMismatch,
        savedSnapshot: savedSnapshot,
        activeSnapshot: activeSnapshot,
      );
    }
  }

  return FitBundleCompatibility.compatible(
    savedSnapshot: savedSnapshot,
    activeSnapshot: activeSnapshot,
  );
}

final fitBundleCompatibilityProvider = Provider.family<FitBundleCompatibility?, String>((
  ref,
  fitId,
) {
  final metadata = ref.watch(fitRegistryManagerProvider.select((registry) => registry.fits[fitId]));
  if (metadata == null) {
    return null;
  }

  final activeBundle = ref.watch(currentBundleProvider);
  return evaluateFitBundleCompatibility(metadata, activeBundle);
});
