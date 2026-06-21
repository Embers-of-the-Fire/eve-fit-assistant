import "package:eve_fit_assistant/components/wizard/wizard_action_bar.dart";
import "package:eve_fit_assistant/components/wizard/wizard_tokens.dart";
import "package:eve_fit_assistant/utils/screen.dart";
import "package:flutter/material.dart";

/// Responsive page shell shared by wizard steps.
///
/// Renders a title, subtitle, content area and a [WizardActionBar]. The action
/// area is data-driven: a [primaryLabel]/[onPrimary] pair plus an extensible
/// list of [secondaryActions]. Steps compose their content and actions
/// declaratively instead of re-implementing the page layout.
class WizardScaffold extends StatelessWidget {
  const WizardScaffold({
    required this.title,
    required this.subtitle,
    required this.content,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryActions = const [],
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget content;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final List<WizardAction> secondaryActions;

  @override
  Widget build(BuildContext context) {
    final tokens = WizardTokens.of(context);
    final isPhone = screenColumnTarget(context) == ScreenColumnTarget.one;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacingXl, vertical: tokens.spacingLg),
          child: isPhone ? _buildPhoneLayout(context, tokens) : _buildTabletLayout(context, tokens),
        ),
      ),
    );
  }

  Widget _buildPhoneLayout(BuildContext context, WizardTokens tokens) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: tokens.spacingXxl),
        Text(title, style: theme.textTheme.headlineMedium),
        SizedBox(height: tokens.spacingXs),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        SizedBox(height: tokens.spacingXxl),
        content,
        SizedBox(height: tokens.spacingXl),
        WizardActionBar(
          primaryLabel: primaryLabel,
          onPrimary: onPrimary,
          layout: WizardActionBarLayout.stacked,
          secondary: secondaryActions,
        ),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context, WizardTokens tokens) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacingXxl * 2.5,
        vertical: tokens.spacingXxl,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.headlineMedium,
                        textAlign: TextAlign.right,
                      ),
                      SizedBox(height: tokens.spacingSm),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: EdgeInsets.only(left: tokens.spacingXxl + tokens.spacingLg),
                    child: content,
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacingXxl + tokens.spacingSm),
            WizardActionBar(
              primaryLabel: primaryLabel,
              onPrimary: onPrimary,
              layout: WizardActionBarLayout.inline,
              secondary: secondaryActions,
            ),
          ],
        ),
      ),
    );
  }
}
