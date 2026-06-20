import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";

class WelcomePage extends StatelessWidget {
  const WelcomePage({required this.onInitialize, required this.onSkip, super.key});

  final VoidCallback onInitialize;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset("logo/logo.png", width: 96, height: 96),
              const SizedBox(height: 24),
              Text(
                context.l10n.appTitle,
                style: Theme.of(
                  context,
                ).textTheme.headlineLarge?.copyWith(fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              FilledButton(
                onPressed: onInitialize,
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                ),
                child: const Icon(Icons.keyboard_double_arrow_right, size: 32),
              ),
              const SizedBox(height: 16),
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
