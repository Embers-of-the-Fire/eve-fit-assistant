import "package:eve_fit_assistant/components/wizard/wizard_tokens.dart";
import "package:flutter/material.dart";

/// Visual style of a secondary [WizardAction].
enum WizardActionStyle { text, outlined }

/// Layout strategy for [WizardActionBar].
enum WizardActionBarLayout {
  /// Primary button centered above a row of secondary actions (phone).
  stacked,

  /// Secondary actions on the leading side, primary on the trailing side
  /// (tablet / wide layouts).
  inline,
}

/// A declarative secondary action rendered by [WizardActionBar].
class WizardAction {
  const WizardAction({
    required this.label,
    required this.onPressed,
    this.style = WizardActionStyle.text,
  });

  final String label;
  final VoidCallback onPressed;
  final WizardActionStyle style;
}

/// The action area shared by wizard steps.
///
/// Provides a single primary action plus an extensible list of secondary
/// actions, keeping button placement consistent across phone and tablet
/// layouts. New step actions are added declaratively via [secondary] rather
/// than by hand-rolling per-step button rows.
class WizardActionBar extends StatelessWidget {
  const WizardActionBar({
    required this.primaryLabel,
    required this.onPrimary,
    required this.layout,
    this.secondary = const [],
    super.key,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final WizardActionBarLayout layout;
  final List<WizardAction> secondary;

  @override
  Widget build(BuildContext context) => switch (layout) {
    WizardActionBarLayout.stacked => _buildStacked(context),
    WizardActionBarLayout.inline => _buildInline(context),
  };

  Widget _buildPrimary(BuildContext context) =>
      FilledButton(onPressed: onPrimary, child: Text(primaryLabel));

  Widget _buildSecondary(BuildContext context, WizardAction action) => switch (action.style) {
    WizardActionStyle.text => TextButton(onPressed: action.onPressed, child: Text(action.label)),
    WizardActionStyle.outlined => OutlinedButton(
      onPressed: action.onPressed,
      child: Text(action.label),
    ),
  };

  Widget _buildStacked(BuildContext context) {
    final tokens = WizardTokens.of(context);
    return Column(
      children: [
        Center(child: _buildPrimary(context)),
        if (secondary.isNotEmpty) ...[
          SizedBox(height: tokens.spacingLg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [for (final action in secondary) _buildSecondary(context, action)],
          ),
        ],
      ],
    );
  }

  Widget _buildInline(BuildContext context) {
    final tokens = WizardTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacingXs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              for (final action in secondary) ...[
                _buildSecondary(context, action),
                SizedBox(width: tokens.spacingSm),
              ],
            ],
          ),
          _buildPrimary(context),
        ],
      ),
    );
  }
}
