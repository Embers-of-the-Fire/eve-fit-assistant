import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/storage/fit/compatibility.dart";

enum FitCheckoutCompatibilityAction { none, openBranchManager }

class FitCheckoutCompatibilityNotice {
  const FitCheckoutCompatibilityNotice({
    required this.title,
    required this.message,
    required this.label,
    this.action = FitCheckoutCompatibilityAction.none,
    this.actionLabel,
  });

  final String title;
  final String message;
  final String label;
  final FitCheckoutCompatibilityAction action;
  final String? actionLabel;
}

FitCheckoutCompatibilityNotice? localizeFitCheckoutCompatibility(
  AppLocalizations l10n,
  FitCheckoutCompatibility? compatibility,
) {
  if (compatibility == null || !compatibility.requiresAttention) {
    return null;
  }

  return switch (compatibility.kind) {
    FitCheckoutCompatibilityKind.compatible => null,
    FitCheckoutCompatibilityKind.outdated => FitCheckoutCompatibilityNotice(
      title: l10n.fitCheckoutChangedTitle,
      message: l10n.fitCheckoutChangedDescription,
      label: l10n.fitCheckoutChangedTitle,
      action: FitCheckoutCompatibilityAction.openBranchManager,
      actionLabel: l10n.fitCheckoutOpenManagerAction,
    ),
    FitCheckoutCompatibilityKind.incompatible => FitCheckoutCompatibilityNotice(
      title: l10n.fitCheckoutMismatchTitle,
      message: l10n.fitCheckoutMismatchDescription(
        savedCheckoutId: compatibility.checkoutRef.checkoutId,
        activeCheckoutId: compatibility.activeCheckoutId,
      ),
      label: l10n.fitCheckoutMismatchTitle,
      action: FitCheckoutCompatibilityAction.openBranchManager,
      actionLabel: l10n.fitCheckoutOpenManagerAction,
    ),
  };
}
