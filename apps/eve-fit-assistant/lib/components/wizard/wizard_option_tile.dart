import "package:eve_fit_assistant/components/wizard/wizard_tokens.dart";
import "package:flutter/material.dart";

/// The trailing control rendered by a [WizardOptionTile].
enum WizardOptionControl {
  /// Single-select: a check mark appears when selected (default).
  radio,

  /// Multi-select: a Material [Checkbox].
  checkbox,

  /// On/off: a Material [Switch].
  toggle,
}

/// A selectable card used by wizard steps.
///
/// This is the single source of truth for the selection-tile style shared by
/// every step (language, channel, server, ...). Steps configure it via
/// [title], optional [subtitle] (e.g. a "Detected" hint), optional [badge]
/// (e.g. a "default" pill) and the [control] type; style changes live here.
class WizardOptionTile extends StatelessWidget {
  const WizardOptionTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.control = WizardOptionControl.radio,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;
  final WizardOptionControl control;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tokens = WizardTokens.of(context);
    final radius = BorderRadius.circular(tokens.cardRadius);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.3),
          width: selected ? 2 : 1,
        ),
      ),
      color: selected ? colorScheme.primaryContainer.withValues(alpha: 0.2) : null,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: tokens.cardPadding,
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
                              fontWeight: selected ? FontWeight.w600 : null,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          SizedBox(width: tokens.spacingSm),
                          _Badge(label: badge!, tokens: tokens, colorScheme: colorScheme),
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
              _buildControl(context, tokens, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControl(BuildContext context, WizardTokens tokens, ColorScheme colorScheme) =>
      switch (control) {
        WizardOptionControl.radio =>
          selected
              ? Icon(Icons.check, color: colorScheme.primary, size: tokens.selectedIconSize)
              : SizedBox(width: tokens.selectedIconSize),
        WizardOptionControl.checkbox => Checkbox(value: selected, onChanged: (_) => onTap()),
        WizardOptionControl.toggle => Switch(value: selected, onChanged: (_) => onTap()),
      };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.tokens, required this.colorScheme});

  final String label;
  final WizardTokens tokens;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) => Container(
    padding: tokens.badgePadding,
    decoration: BoxDecoration(
      color: colorScheme.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(tokens.badgeRadius),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.primary),
    ),
  );
}

/// Lays out a vertical list of [WizardOptionTile]s with consistent spacing.
class WizardOptionList extends StatelessWidget {
  const WizardOptionList({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = WizardTokens.of(context);
    return Column(
      children: [
        for (final child in children)
          Padding(
            padding: EdgeInsets.only(bottom: tokens.spacingMd),
            child: child,
          ),
      ],
    );
  }
}
