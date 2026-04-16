import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/storage/fit/compatibility.dart";

enum FitBundleCompatibilityAction { none, openBundleManager, switchToSavedBundle }

class FitBundleCompatibilityNotice {
  const FitBundleCompatibilityNotice({
    required this.title,
    required this.message,
    required this.label,
    this.action = FitBundleCompatibilityAction.none,
    this.actionLabel,
    this.actionBundleId,
  });

  final String title;
  final String message;
  final String label;
  final FitBundleCompatibilityAction action;
  final String? actionLabel;
  final String? actionBundleId;
}

FitBundleCompatibilityNotice? localizeFitBundleCompatibility(
  AppLocalizations l10n,
  FitBundleCompatibility? compatibility,
) {
  if (compatibility == null || !compatibility.requiresAttention) {
    return null;
  }

  return switch (compatibility.kind) {
    FitBundleCompatibilityKind.compatible => null,
    FitBundleCompatibilityKind.outdated => switch (compatibility.reason) {
      FitBundleCompatibilityReason.missingComparableRevision => FitBundleCompatibilityNotice(
        title: l10n.fitBundleLegacyTitle,
        message: l10n.fitBundleLegacyDescription,
        label: l10n.fitBundleLegacyTitle,
        action: FitBundleCompatibilityAction.openBundleManager,
        actionLabel: l10n.fitBundleOpenManagerAction,
      ),
      _ => FitBundleCompatibilityNotice(
        title: l10n.fitBundleChangedTitle,
        message: l10n.fitBundleChangedDescription,
        label: l10n.fitBundleChangedTitle,
        action: FitBundleCompatibilityAction.openBundleManager,
        actionLabel: l10n.fitBundleOpenManagerAction,
      ),
    },
    FitBundleCompatibilityKind.incompatible => () {
      final activeSnapshot = compatibility.activeSnapshot;
      if (activeSnapshot == null) {
        throw StateError("Incompatible fit bundle compatibility requires an active snapshot.");
      }

      return compatibility.savedBundleAllowsEditing
          ? FitBundleCompatibilityNotice(
              title: l10n.fitBundleMismatchTitle,
              message: l10n.fitBundleMismatchSwitchDescription(
                savedBundleId: compatibility.savedSnapshot.bundleId,
                activeBundleId: activeSnapshot.bundleId,
              ),
              label: l10n.fitBundleSwitchLabel,
              action: FitBundleCompatibilityAction.switchToSavedBundle,
              actionLabel: l10n.fitBundleSwitchAction,
              actionBundleId: compatibility.savedSnapshot.bundleId,
            )
          : FitBundleCompatibilityNotice(
              title: l10n.fitBundleMismatchTitle,
              message: compatibility.savedBundleInstalled
                  ? l10n.fitBundleMismatchDescription(
                      savedBundleId: compatibility.savedSnapshot.bundleId,
                      activeBundleId: activeSnapshot.bundleId,
                    )
                  : l10n.fitBundleMismatchImportDescription(
                      savedBundleId: compatibility.savedSnapshot.bundleId,
                      activeBundleId: activeSnapshot.bundleId,
                    ),
              label: compatibility.savedBundleInstalled
                  ? l10n.fitBundleMismatchTitle
                  : l10n.fitBundleImportLabel,
              action: FitBundleCompatibilityAction.openBundleManager,
              actionLabel: l10n.fitBundleOpenManagerAction,
            );
    }(),
    FitBundleCompatibilityKind.unavailable =>
      compatibility.savedBundleAllowsEditing
          ? FitBundleCompatibilityNotice(
              title: l10n.fitBundleUnavailableTitle,
              message: l10n.fitBundleUnavailableSwitchDescription(
                savedBundleId: compatibility.savedSnapshot.bundleId,
              ),
              label: l10n.fitBundleSwitchLabel,
              action: FitBundleCompatibilityAction.switchToSavedBundle,
              actionLabel: l10n.fitBundleSwitchAction,
              actionBundleId: compatibility.savedSnapshot.bundleId,
            )
          : FitBundleCompatibilityNotice(
              title: l10n.fitBundleUnavailableTitle,
              message: compatibility.savedBundleInstalled
                  ? l10n.fitBundleUnavailableDescription
                  : l10n.fitBundleUnavailableImportDescription,
              label: compatibility.savedBundleInstalled
                  ? l10n.fitBundleUnavailableTitle
                  : l10n.fitBundleImportLabel,
              action: FitBundleCompatibilityAction.openBundleManager,
              actionLabel: l10n.fitBundleOpenManagerAction,
            ),
  };
}
