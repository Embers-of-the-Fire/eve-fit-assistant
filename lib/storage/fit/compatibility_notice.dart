import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/storage/fit/compatibility.dart";

class FitBundleCompatibilityNotice {
  const FitBundleCompatibilityNotice({
    required this.title,
    required this.message,
    required this.label,
  });

  final String title;
  final String message;
  final String label;
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
    FitBundleCompatibilityKind.outdated => FitBundleCompatibilityNotice(
      title: l10n.fitBundleChangedTitle,
      message: l10n.fitBundleChangedDescription,
      label: l10n.fitBundleChangedTitle,
    ),
    FitBundleCompatibilityKind.incompatible => FitBundleCompatibilityNotice(
      title: l10n.fitBundleMismatchTitle,
      message: l10n.fitBundleMismatchDescription(
        savedBundleId: compatibility.savedSnapshot.bundleId,
        activeBundleId: compatibility.activeSnapshot?.bundleId ?? "-",
      ),
      label: l10n.fitBundleMismatchTitle,
    ),
    FitBundleCompatibilityKind.unavailable => FitBundleCompatibilityNotice(
      title: l10n.fitBundleUnavailableTitle,
      message: l10n.fitBundleUnavailableDescription,
      label: l10n.fitBundleUnavailableTitle,
    ),
  };
}
