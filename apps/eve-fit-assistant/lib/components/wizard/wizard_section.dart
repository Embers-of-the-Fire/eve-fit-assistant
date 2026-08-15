import "package:eve_fit_assistant/components/wizard/wizard_tokens.dart";
import "package:flutter/material.dart";

/// A titled section header for grouping wizard content.
class WizardSectionHeader extends StatelessWidget {
  const WizardSectionHeader({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = WizardTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        if (subtitle != null) ...[
          SizedBox(height: tokens.spacingXs),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// An icon + text informational row used to explain wizard content.
class WizardInfoRow extends StatelessWidget {
  const WizardInfoRow({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = WizardTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: tokens.selectedIconSize, color: theme.colorScheme.onSurfaceVariant),
        SizedBox(width: tokens.spacingSm),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
