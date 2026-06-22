import "package:eve_fit_assistant/components/wizard/wizard.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";

class WelcomePage extends StatelessWidget {
  const WelcomePage({required this.onInitialize, required this.onSkip, super.key});

  final VoidCallback onInitialize;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final tokens = WizardTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacingXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset("logo/logo.png", width: 96, height: 96),
                SizedBox(height: tokens.spacingXl),
                Text(
                  context.l10n.appTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineLarge?.copyWith(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: tokens.spacingXxl + tokens.spacingSm),
                FilledButton(
                  onPressed: onInitialize,
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacingXxl + tokens.spacingLg,
                      vertical: tokens.spacingXl - tokens.spacingXs,
                    ),
                  ),
                  child: const Icon(Icons.keyboard_double_arrow_right, size: 32),
                ),
                SizedBox(height: tokens.spacingLg),
                IconButton(
                  onPressed: onSkip,
                  icon: const Icon(Icons.logout),
                  tooltip: context.l10n.welcomeSkipButton,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
