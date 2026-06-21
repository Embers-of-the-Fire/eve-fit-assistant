import "package:eve_fit_assistant/components/wizard/wizard_tokens.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Renders the shared loading / error / data states for an [AsyncValue] inside
/// a wizard step, so individual steps do not re-implement spinners and retry
/// UI. The [retryLabel] is supplied by the call site to keep the kit free of
/// app-specific localization keys.
class WizardAsyncContent<T> extends StatelessWidget {
  const WizardAsyncContent({
    required this.value,
    required this.onRetry,
    required this.errorMessage,
    required this.retryLabel,
    required this.builder,
    super.key,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final String errorMessage;
  final String retryLabel;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) => value.when(
    loading: () => const _WizardContentLoading(),
    error: (_, _) =>
        WizardContentMessage(message: errorMessage, retryLabel: retryLabel, onRetry: onRetry),
    data: builder,
  );
}

class _WizardContentLoading extends StatelessWidget {
  const _WizardContentLoading();

  @override
  Widget build(BuildContext context) {
    final tokens = WizardTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.contentVerticalPadding + tokens.spacingLg),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

/// A centered informational message with a retry button, used for error and
/// empty states in wizard steps.
class WizardContentMessage extends StatelessWidget {
  const WizardContentMessage({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    super.key,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = WizardTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.contentVerticalPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            size: tokens.statusIconSize,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          SizedBox(height: tokens.spacingMd),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          SizedBox(height: tokens.spacingLg),
          OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}
