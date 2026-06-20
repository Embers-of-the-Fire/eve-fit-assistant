import "package:eve_fit_assistant/constant/colors.dart";
import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/features/welcome/language_step.dart";
import "package:eve_fit_assistant/features/welcome/page.dart";
import "package:eve_fit_assistant/features/welcome/sub_step.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class WelcomeGate extends ConsumerStatefulWidget {
  const WelcomeGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends ConsumerState<WelcomeGate> {
  @override
  Widget build(BuildContext context) {
    if (ref.watch(appSettingServiceProvider.select((s) => s.welcomeCompleted))) {
      return widget.child;
    }

    return _WelcomeFlowHost(
      onComplete: () {
        ref
            .read(appSettingServiceProvider.notifier)
            .update((s) => s.copyWith(welcomeCompleted: true));
      },
    );
  }
}

class _WelcomeFlowHost extends ConsumerStatefulWidget {
  const _WelcomeFlowHost({required this.onComplete});

  final VoidCallback onComplete;

  @override
  ConsumerState<_WelcomeFlowHost> createState() => _WelcomeFlowHostState();
}

class _WelcomeFlowHostState extends ConsumerState<_WelcomeFlowHost> {
  int _stepIndex = 0;
  bool _initializing = false;

  static const int _placeholderSteps = 2;

  int get _totalSteps => 2 + _placeholderSteps;

  void _startInitialize() {
    setState(() {
      _initializing = true;
      _stepIndex = 1;
    });
  }

  void _backToIntro() {
    setState(() {
      _initializing = false;
      _stepIndex = 0;
    });
  }

  void _nextStep() {
    if (_stepIndex >= _totalSteps - 1) {
      widget.onComplete();
      return;
    }
    setState(() {
      _stepIndex++;
    });
  }

  void _skip() {
    widget.onComplete();
  }

  static final ThemeData _lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: primaryBlue),
    scaffoldBackgroundColor: const Color(0xFFE8F1F0),
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: _lightTheme,
    locale: Locale(ref.watch(localeProvider).name),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) {
        if (!_initializing) {
          return WelcomePage(onInitialize: _startInitialize, onSkip: _skip);
        }

        if (_stepIndex == 1) {
          return LanguageStepPage(onContinue: _nextStep, onSkip: _skip, onBack: _backToIntro);
        }

        final subStepNumber = _stepIndex - 1;
        final isLast = subStepNumber >= _placeholderSteps;
        return SubStepPage(
          stepNumber: subStepNumber,
          totalSteps: _placeholderSteps,
          onNext: _nextStep,
          isLast: isLast,
        );
      },
    ),
  );
}
