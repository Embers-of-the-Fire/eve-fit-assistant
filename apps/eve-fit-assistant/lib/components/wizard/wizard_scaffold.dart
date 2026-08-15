import "package:eve_fit_assistant/components/wizard/wizard_action_bar.dart";
import "package:eve_fit_assistant/components/wizard/wizard_rotating_header.dart";
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
    this.primaryEnabled = true,
    this.headerBuilder,
    this.secondaryActions = const [],
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget content;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool primaryEnabled;

  /// Optional override for the default animated [title]/[subtitle] header.
  ///
  /// When provided, the returned widget replaces the rotating-title + typing-
  /// subtitle animation. The scaffold passes the layout's text alignment (left
  /// on phones, right on tablets) so the header matches the surrounding text.
  /// The [title]/[subtitle] strings remain the fallback when this is `null`.
  final Widget Function(TextAlign alignment)? headerBuilder;

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

  Widget _buildPhoneLayout(BuildContext context, WizardTokens tokens) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(height: tokens.spacingXxl),
      if (headerBuilder != null)
        headerBuilder!(TextAlign.left)
      else
        WizardRotatingHeader(
          title: title,
          details: [subtitle],
          animationKey: ValueKey(title),
          textAlign: TextAlign.left,
        ),
      SizedBox(height: tokens.spacingXl),
      Expanded(child: SingleChildScrollView(child: content)),
      SizedBox(height: tokens.spacingLg),
      WizardActionBar(
        primaryLabel: primaryLabel,
        onPrimary: onPrimary,
        primaryEnabled: primaryEnabled,
        layout: WizardActionBarLayout.stacked,
        secondary: secondaryActions,
      ),
    ],
  );

  Widget _buildTabletLayout(BuildContext context, WizardTokens tokens) => Padding(
    padding: EdgeInsets.symmetric(horizontal: tokens.spacingXxl * 2.5, vertical: tokens.spacingXxl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WizardActionBar(
          primaryLabel: primaryLabel,
          onPrimary: onPrimary,
          primaryEnabled: primaryEnabled,
          layout: WizardActionBarLayout.inline,
          secondary: secondaryActions,
        ),
        SizedBox(height: tokens.spacingXxl + tokens.spacingSm),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: headerBuilder != null
                    ? headerBuilder!(TextAlign.right)
                    : WizardRotatingHeader(
                        title: title,
                        details: [subtitle],
                        animationKey: ValueKey(title),
                        textAlign: TextAlign.right,
                      ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.only(left: tokens.spacingXxl + tokens.spacingLg),
                  child: SingleChildScrollView(child: content),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
