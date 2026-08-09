import "package:eve_fit_assistant/components/wizard/wizard.dart";
import "package:eve_fit_assistant/config/storage_root.dart";
import "package:eve_fit_assistant/constant/colors.dart";
import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/features/welcome/channel_step.dart";
import "package:eve_fit_assistant/features/welcome/language_step.dart";
import "package:eve_fit_assistant/features/welcome/page.dart";
import "package:eve_fit_assistant/features/welcome/provisioning_step.dart";
import "package:eve_fit_assistant/features/welcome/server_step.dart";
import "package:eve_fit_assistant/features/welcome/storage_step.dart";
import "package:eve_fit_assistant/storage/repo/generation_nav.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
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
    final welcomeCompleted = ref.watch(appSettingServiceProvider.select((s) => s.welcomeCompleted));

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 700),
      layoutBuilder: (currentChild, previousChildren) =>
          Stack(alignment: Alignment.topLeft, children: [...previousChildren, ?currentChild]),
      child: welcomeCompleted
          ? KeyedSubtree(key: const ValueKey("app"), child: widget.child)
          : KeyedSubtree(
              key: const ValueKey("wizard"),
              child: _WelcomeFlowHost(
                onComplete: () {
                  ref
                      .read(appSettingServiceProvider.notifier)
                      .update((s) => s.copyWith(welcomeCompleted: true));
                },
              ),
            ),
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
  String _selectedChannel = Channel.defaultChannel.value;
  IList<ProvisioningTarget>? _selectedTargets;
  String? _generationHash;

  int get _stepCount => 4 + (storageRootEditable ? 1 : 0);

  int get _totalSteps => 1 + _stepCount;

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

  void _previousStep() {
    setState(() {
      _stepIndex--;
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

  void _onServerContinue(IList<ServerSummary> selectedServers) {
    final locale = ref.read(localeProvider).name;
    final data = ref.read(serverSelectionDataProvider(_selectedChannel)).requireValue;

    final targets = selectedServers
        .where((server) => data.snapshotHashForServer.containsKey(server.serverId))
        .map(
          (server) => ProvisioningTarget(
            serverId: server.serverId,
            displayName: server.displayName(locale),
            snapshotHash: data.snapshotHashForServer[server.serverId]!,
          ),
        )
        .toIList();

    setState(() {
      _selectedTargets = targets;
      _generationHash = data.generationHash;
    });
    _nextStep();
  }

  static final ThemeData _lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: primaryBlue),
    scaffoldBackgroundColor: const Color(0xFFE8F1F0),
    extensions: const [WizardTokens.standard],
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

        final steps = <Widget Function()>[
          () => LanguageStepPage(onContinue: _nextStep, onSkip: _skip, onBack: _backToIntro),
          if (storageRootEditable)
            () => StorageStepPage(onContinue: _nextStep, onSkip: _skip, onBack: _previousStep),
          () => ChannelStepPage(
            onContinue: (channelName) {
              setState(() => _selectedChannel = channelName);
              _nextStep();
            },
            onSkip: _skip,
            onBack: _previousStep,
          ),
          () => ServerStepPage(
            channelName: _selectedChannel,
            onContinue: _onServerContinue,
            onSkip: _skip,
            onBack: _previousStep,
          ),
          () => ProvisioningStepPage(
            channel: Channel.tryParse(_selectedChannel) ?? Channel.defaultChannel,
            channelName: _selectedChannel,
            generationHash: _generationHash!,
            targets: _selectedTargets!,
            onComplete: () => widget.onComplete(),
            onBack: _previousStep,
          ),
        ];

        if (_stepIndex < 1 || _stepIndex > steps.length) {
          return WelcomePage(onInitialize: _startInitialize, onSkip: _skip);
        }
        return steps[_stepIndex - 1]();
      },
    ),
  );
}
