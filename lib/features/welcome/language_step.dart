import "dart:ui" as ui;

import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/features/welcome/welcome_step_template.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
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
    final detectedCode = ui.PlatformDispatcher.instance.locale.languageCode;

    void onSelected(Locale value) =>
        ref.read(appSettingServiceProvider.notifier).update((old) => old.copyWith(locale: value));

    return WelcomeStepTemplate(
      title: context.l10n.welcomeLanguageTitle,
      subtitle: context.l10n.welcomeLanguageSubtitle,
      onContinue: onContinue,
      onSkip: onSkip,
      onBack: onBack,
      content: Column(
        children: [
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
        ],
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
