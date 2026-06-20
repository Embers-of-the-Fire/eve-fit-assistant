import "dart:ui" as ui;

import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/screen.dart";
import "package:flutter/material.dart" hide Locale;
import "package:flutter_riverpod/flutter_riverpod.dart";

class LanguageStepPage extends ConsumerWidget {
  const LanguageStepPage({
    required this.onContinue,
    required this.onSkip,
    required this.onBack,
    super.key,
  });

  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(localeProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: screenColumnTarget(context) == ScreenColumnTarget.one
              ? _PhoneLayout(
                  selected: selected,
                  onSelected: (value) => ref
                      .read(appSettingServiceProvider.notifier)
                      .update((old) => old.copyWith(locale: value)),
                  onContinue: onContinue,
                  onSkip: onSkip,
                  onBack: onBack,
                )
              : _TabletLayout(
                  selected: selected,
                  onSelected: (value) => ref
                      .read(appSettingServiceProvider.notifier)
                      .update((old) => old.copyWith(locale: value)),
                  onContinue: onContinue,
                  onSkip: onSkip,
                  onBack: onBack,
                ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.locale,
    required this.isSelected,
    required this.onTap,
    this.isDetected = false,
  });

  final Locale locale;
  final bool isSelected;
  final bool isDetected;
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
                    Text(
                      locale.display,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : null,
                      ),
                    ),
                    if (isDetected)
                      Text(
                        "Detected",
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

class _PhoneLayout extends StatelessWidget {
  const _PhoneLayout({
    required this.selected,
    required this.onSelected,
    required this.onContinue,
    required this.onSkip,
    required this.onBack,
  });

  final Locale selected;
  final void Function(Locale) onSelected;
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final detectedCode = ui.PlatformDispatcher.instance.locale.languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Text(context.l10n.welcomeLanguageTitle, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          context.l10n.welcomeLanguageSubtitle,
          style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 32),
        for (final locale in Locale.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _LanguageCard(
              locale: locale,
              isSelected: locale == selected,
              isDetected: locale.name == detectedCode,
              onTap: () => onSelected(locale),
            ),
          ),
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
}

class _TabletLayout extends StatelessWidget {
  const _TabletLayout({
    required this.selected,
    required this.onSelected,
    required this.onContinue,
    required this.onSkip,
    required this.onBack,
  });

  final Locale selected;
  final void Function(Locale) onSelected;
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final detectedCode = ui.PlatformDispatcher.instance.locale.languageCode;

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
                        context.l10n.welcomeLanguageTitle,
                        style: theme.textTheme.headlineMedium,
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.welcomeLanguageSubtitle,
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
                    padding: const EdgeInsets.only(left: 48),
                    child: Column(
                      children: [
                        for (final locale in Locale.values)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _LanguageCard(
                              locale: locale,
                              isSelected: locale == selected,
                              isDetected: locale.name == detectedCode,
                              onTap: () => onSelected(locale),
                            ),
                          ),
                      ],
                    ),
                  ),
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
