import "package:flutter/material.dart";

class SubStepPage extends StatelessWidget {
  const SubStepPage({
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    this.isLast = false,
    super.key,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Step $stepNumber of $totalSteps",
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Icon(Icons.construction, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                "Coming Soon",
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "This step will be implemented in a future update.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton(onPressed: onNext, child: Text(isLast ? "Get Started" : "Continue")),
            ],
          ),
        ),
      ),
    );
  }
}
