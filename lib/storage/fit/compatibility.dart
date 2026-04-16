import "package:eve_fit_assistant/storage/bundle/manager.dart";
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

enum FitBundleCompatibilityKind { compatible, outdated, incompatible, unavailable }

enum FitSavedBundleAvailability { missing, installedIncompatible, installedCompatible }

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
    required this.savedBundleAvailability,
  });

  const FitBundleCompatibility.compatible({
    required FitBundleSnapshot savedSnapshot,
    required FitBundleSnapshot activeSnapshot,
  }) : this(
         kind: FitBundleCompatibilityKind.compatible,
         reason: FitBundleCompatibilityReason.none,
         savedSnapshot: savedSnapshot,
         activeSnapshot: activeSnapshot,
         savedBundleAvailability: FitSavedBundleAvailability.installedCompatible,
       );

  final FitBundleCompatibilityKind kind;
  final FitBundleCompatibilityReason reason;
  final FitBundleSnapshot savedSnapshot;
  final FitBundleSnapshot? activeSnapshot;
  final FitSavedBundleAvailability savedBundleAvailability;

  bool get allowsEditing => kind == FitBundleCompatibilityKind.compatible;
  bool get requiresAttention => kind != FitBundleCompatibilityKind.compatible;
  bool get savedBundleInstalled => savedBundleAvailability != FitSavedBundleAvailability.missing;
  bool get savedBundleAllowsEditing =>
      savedBundleAvailability == FitSavedBundleAvailability.installedCompatible;
}

FitSavedBundleAvailability evaluateSavedBundleAvailability(
  FitBundleSnapshot savedSnapshot,
  FitBundleSnapshot? installedSavedSnapshot,
) {
  if (installedSavedSnapshot == null) {
    return FitSavedBundleAvailability.missing;
  }

  return _evaluateSnapshotPair(savedSnapshot, installedSavedSnapshot).kind ==
          FitBundleCompatibilityKind.compatible
      ? FitSavedBundleAvailability.installedCompatible
      : FitSavedBundleAvailability.installedIncompatible;
}

FitSavedBundleAvailability resolveSavedBundleAvailability(
  FitBundleSnapshot savedSnapshot,
  BundleMetadata? activeBundle, {
  required bool savedBundleInstalled,
}) {
  if (!savedBundleInstalled) {
    return FitSavedBundleAvailability.missing;
  }

  final installedSavedSnapshot = switch (activeBundle) {
    final bundle? when bundle.bundleId == savedSnapshot.bundleId =>
      FitBundleSnapshot.fromBundleMetadata(bundle),
    _ => () {
      try {
        final registrar = BundleRegistryManager.getRegistrar(savedSnapshot.bundleId);
        if (registrar.history.isEmpty) {
          return null;
        }
        return FitBundleSnapshot(
          bundleId: registrar.bundleId,
          manifestHash: registrar.latest.manifestHash,
          gameBuild: registrar.latest.gameBuild,
          appVersion: registrar.latest.appVersion,
          generateTimestamp: registrar.latest.generateTimestamp,
        );
      } on Object {
        return null;
      }
    }(),
  };

  return evaluateSavedBundleAvailability(savedSnapshot, installedSavedSnapshot);
}

({FitBundleCompatibilityKind kind, FitBundleCompatibilityReason reason}) _evaluateSnapshotPair(
  FitBundleSnapshot savedSnapshot,
  FitBundleSnapshot activeSnapshot,
) {
  if (savedSnapshot.bundleId != activeSnapshot.bundleId) {
    return (
      kind: FitBundleCompatibilityKind.incompatible,
      reason: FitBundleCompatibilityReason.bundleIdMismatch,
    );
  }

  if (!savedSnapshot.hasComparableRevision || !activeSnapshot.hasComparableRevision) {
    return (
      kind: FitBundleCompatibilityKind.outdated,
      reason: FitBundleCompatibilityReason.missingComparableRevision,
    );
  }

  if (savedSnapshot.manifestHash case final savedManifestHash?) {
    final activeManifestHash = activeSnapshot.manifestHash;
    if (activeManifestHash != null && savedManifestHash != activeManifestHash) {
      return (
        kind: FitBundleCompatibilityKind.outdated,
        reason: FitBundleCompatibilityReason.manifestMismatch,
      );
    }
  }

  if (savedSnapshot.generateTimestamp case final savedGenerateTimestamp?) {
    final activeGenerateTimestamp = activeSnapshot.generateTimestamp;
    if (activeGenerateTimestamp != null && savedGenerateTimestamp != activeGenerateTimestamp) {
      return (
        kind: FitBundleCompatibilityKind.outdated,
        reason: FitBundleCompatibilityReason.generationMismatch,
      );
    }
  }

  if (savedSnapshot.gameBuild case final savedGameBuild?) {
    final activeGameBuild = activeSnapshot.gameBuild;
    if (activeGameBuild != null && savedGameBuild != activeGameBuild) {
      return (
        kind: FitBundleCompatibilityKind.outdated,
        reason: FitBundleCompatibilityReason.buildMismatch,
      );
    }
  }

  if (savedSnapshot.appVersion case final savedAppVersion?) {
    final activeAppVersion = activeSnapshot.appVersion;
    if (activeAppVersion != null && savedAppVersion != activeAppVersion) {
      return (
        kind: FitBundleCompatibilityKind.outdated,
        reason: FitBundleCompatibilityReason.appVersionMismatch,
      );
    }
  }

  return (kind: FitBundleCompatibilityKind.compatible, reason: FitBundleCompatibilityReason.none);
}

FitBundleCompatibility evaluateFitBundleCompatibility(
  FitMetadata metadata,
  BundleMetadata? activeBundle, {
  required FitSavedBundleAvailability savedBundleAvailability,
}) {
  final savedSnapshot = metadata.bundleSnapshot;
  if (activeBundle == null) {
    return FitBundleCompatibility(
      kind: FitBundleCompatibilityKind.unavailable,
      reason: FitBundleCompatibilityReason.activeBundleUnavailable,
      savedSnapshot: savedSnapshot,
      activeSnapshot: null,
      savedBundleAvailability: savedBundleAvailability,
    );
  }

  final activeSnapshot = FitBundleSnapshot.fromBundleMetadata(activeBundle);
  final result = _evaluateSnapshotPair(savedSnapshot, activeSnapshot);
  if (result.kind != FitBundleCompatibilityKind.compatible) {
    return FitBundleCompatibility(
      kind: result.kind,
      reason: result.reason,
      savedSnapshot: savedSnapshot,
      activeSnapshot: activeSnapshot,
      savedBundleAvailability: savedBundleAvailability,
    );
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

  final savedSnapshot = metadata.bundleSnapshot;
  final activeBundle = ref.watch(currentBundleProvider);
  final savedBundleAvailability = ref.watch(
    bundleRegistryManagerProvider.select(
      (registry) => resolveSavedBundleAvailability(
        savedSnapshot,
        activeBundle,
        savedBundleInstalled: registry.bundles.containsKey(savedSnapshot.bundleId),
      ),
    ),
  );
  return evaluateFitBundleCompatibility(
    metadata,
    activeBundle,
    savedBundleAvailability: savedBundleAvailability,
  );
});
