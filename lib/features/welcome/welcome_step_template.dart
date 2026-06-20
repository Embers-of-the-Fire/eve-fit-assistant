import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/screen.dart";
import "package:flutter/material.dart";

class WelcomeStepTemplate extends StatelessWidget {
  const WelcomeStepTemplate({
    required this.title,
    required this.subtitle,
    required this.content,
    required this.onContinue,
    required this.onSkip,
    required this.onBack,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget content;
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isPhone = screenColumnTarget(context) == ScreenColumnTarget.one;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: isPhone ? _buildPhoneLayout(context) : _buildTabletLayout(context),
        ),
      ),
    );
  }

  Widget _buildPhoneLayout(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Text(title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 32),
        content,
        const SizedBox(height: 24),
        Center(
          child: FilledButton(
            onPressed: onContinue,
            child: Text(context.l10n.welcomeContinueButton),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(onPressed: onBack, child: Text(context.l10n.welcomeBackButton)),
            TextButton(onPressed: onSkip, child: Text(context.l10n.welcomeSkipButton)),
          ],
        ),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 32),
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
                      const SizedBox(height: 8),
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
                  child: Padding(padding: const EdgeInsets.only(left: 48), child: content),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      TextButton(onPressed: onBack, child: Text(context.l10n.welcomeBackButton)),
                      const SizedBox(width: 8),
                      TextButton(onPressed: onSkip, child: Text(context.l10n.welcomeSkipButton)),
                    ],
                  ),
                  FilledButton(
                    onPressed: onContinue,
                    child: Text(context.l10n.welcomeContinueButton),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
