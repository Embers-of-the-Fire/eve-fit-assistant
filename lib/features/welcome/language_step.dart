import "dart:ui" as ui;

import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/features/welcome/welcome_components.dart";
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
      content: WelcomeSelectionList(
        children: [
          for (final locale in Locale.values)
            WelcomeSelectionCard(
              title: locale.display,
              subtitle: locale.name == detectedCode ? "Detected" : null,
              isSelected: locale == selected,
              onTap: () => onSelected(locale),
            ),
        ],
      ),
    );
  }
}
