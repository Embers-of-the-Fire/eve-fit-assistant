import "dart:async";
import "dart:ui" as ui;

import "package:eve_fit_assistant/components/wizard/wizard.dart";
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/features/locale_switch/locale_switch_dialog.dart";
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

    void onSelected(Locale value) {
      ref.read(appSettingServiceProvider.notifier).update((old) => old.copyWith(locale: value));
      // Evaluated after the choice is persisted. In the wizard the per-locale
      // database is usually downloaded eagerly by the provisioning step that
      // follows, so this is a no-op (availability: available) or offers the
      // §5.2 dialog for checkouts provisioned before the split.
      unawaited(offerLocaleLocalizationDb(context, ref, value));
    }

    return WizardScaffold(
      title: context.l10n.welcomeLanguageTitle,
      subtitle: context.l10n.welcomeLanguageSubtitle,
      primaryLabel: context.l10n.welcomeContinueButton,
      onPrimary: onContinue,
      secondaryActions: [
        WizardAction(label: context.l10n.welcomeBackButton, onPressed: onBack),
        WizardAction(label: context.l10n.welcomeSkipButton, onPressed: onSkip),
      ],
      content: WizardOptionList(
        children: [
          for (final locale in Locale.values)
            WizardOptionTile(
              title: locale.display,
              subtitle: locale.name == detectedCode
                  ? context.l10n.welcomeLanguageDetectedBadge
                  : null,
              selected: locale == selected,
              onTap: () => onSelected(locale),
            ),
        ],
      ),
    );
  }
}
