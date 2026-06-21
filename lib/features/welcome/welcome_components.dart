import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// A selectable card used by welcome wizard steps.
///
/// This is the single source of truth for the selection-card style shared by
/// every step (language, channel, server, ...). Steps configure it via
/// [title], optional [subtitle] (e.g. a "Detected" hint) and optional [badge]
/// (e.g. a "default" pill); style changes live here, not in the steps.
class WelcomeSelectionCard extends StatelessWidget {
  const WelcomeSelectionCard({
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
    this.badge,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.2) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: isSelected ? FontWeight.w600 : null,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (isSelected) Icon(Icons.check, color: colorScheme.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays out a vertical list of welcome selection cards with consistent spacing.
class WelcomeSelectionList extends StatelessWidget {
  const WelcomeSelectionList({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final child in children)
        Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
    ],
  );
}

/// Renders the shared loading / error / data states for an [AsyncValue] inside a
/// welcome step, so individual steps do not re-implement spinners and retry UI.
class WelcomeAsyncContent<T> extends StatelessWidget {
  const WelcomeAsyncContent({
    required this.value,
    required this.onRetry,
    required this.errorMessage,
    required this.builder,
    super.key,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final String errorMessage;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) => value.when(
    loading: () => const _WelcomeContentLoading(),
    error: (_, _) => WelcomeContentMessage(message: errorMessage, onRetry: onRetry),
    data: builder,
  );
}

class _WelcomeContentLoading extends StatelessWidget {
  const _WelcomeContentLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 48),
    child: Center(child: CircularProgressIndicator()),
  );
}

/// A centered informational message with a retry button, used for error and
/// empty states in welcome steps.
class WelcomeContentMessage extends StatelessWidget {
  const WelcomeContentMessage({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: Text(context.l10n.fitPageRetryAction)),
        ],
      ),
    );
  }
}
