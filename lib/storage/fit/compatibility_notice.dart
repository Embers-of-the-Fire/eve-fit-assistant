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
    FitBundleCompatibilityKind.incompatible =>
      compatibility.savedBundleInstalled
          ? FitBundleCompatibilityNotice(
              title: l10n.fitBundleMismatchTitle,
              message: l10n.fitBundleMismatchSwitchDescription(
                savedBundleId: compatibility.savedSnapshot.bundleId,
                activeBundleId: compatibility.activeSnapshot?.bundleId ?? "-",
              ),
              label: l10n.fitBundleSwitchLabel,
              action: FitBundleCompatibilityAction.switchToSavedBundle,
              actionLabel: l10n.fitBundleSwitchAction,
              actionBundleId: compatibility.savedSnapshot.bundleId,
            )
          : FitBundleCompatibilityNotice(
              title: l10n.fitBundleMismatchTitle,
              message: l10n.fitBundleMismatchImportDescription(
                savedBundleId: compatibility.savedSnapshot.bundleId,
                activeBundleId: compatibility.activeSnapshot?.bundleId ?? "-",
              ),
              label: l10n.fitBundleImportLabel,
              action: FitBundleCompatibilityAction.openBundleManager,
              actionLabel: l10n.fitBundleOpenManagerAction,
            ),
    FitBundleCompatibilityKind.unavailable =>
      compatibility.savedBundleInstalled
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
              message: l10n.fitBundleUnavailableImportDescription,
              label: l10n.fitBundleImportLabel,
              action: FitBundleCompatibilityAction.openBundleManager,
              actionLabel: l10n.fitBundleOpenManagerAction,
            ),
  };
}
