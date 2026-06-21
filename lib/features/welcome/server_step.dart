import "package:eve_fit_assistant/components/wizard/wizard.dart";
import "package:eve_fit_assistant/storage/repo/generation_nav.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart" show localeProvider;
import "package:eve_fit_assistant/utils/context.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class ServerStepPage extends ConsumerStatefulWidget {
  const ServerStepPage({
    required this.channelName,
    required this.onContinue,
    required this.onSkip,
    required this.onBack,
    super.key,
  });

  final String channelName;
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  @override
  ConsumerState<ServerStepPage> createState() => _ServerStepPageState();
}

class _ServerStepPageState extends ConsumerState<ServerStepPage> {
  final Set<String> _selected = {};
  String? _activeId;

  @override
  void didUpdateWidget(ServerStepPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelName != widget.channelName) {
      _selected.clear();
      _activeId = null;
    }
  }

  void _toggle(String serverId) {
    setState(() {
      if (_selected.contains(serverId)) {
        _selected.remove(serverId);
        _activeId = null;
      } else {
        _selected.add(serverId);
        _activeId = serverId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider).name;
    final servers = ref.watch(serverListProvider(widget.channelName));

    final focusedServer = _findServer(servers.value, _activeId);

    return WizardScaffold(
      title: context.l10n.welcomeServerTitle,
      subtitle: context.l10n.welcomeServerSubtitle,
      headerBuilder: focusedServer == null
          ? null
          : (alignment) => WizardRotatingHeader(
              title: focusedServer.displayName(locale),
              details: _detailsFor(context, focusedServer),
              animationKey: ValueKey(focusedServer.serverId),
              textAlign: alignment,
            ),
      primaryLabel: context.l10n.welcomeContinueButton,
      onPrimary: widget.onContinue,
      secondaryActions: [
        WizardAction(label: context.l10n.welcomeBackButton, onPressed: widget.onBack),
        WizardAction(label: context.l10n.welcomeSkipButton, onPressed: widget.onSkip),
      ],
      content: WizardAsyncContent(
        value: servers,
        onRetry: () => ref.invalidate(serverListProvider(widget.channelName)),
        errorMessage: context.l10n.welcomeServerError,
        retryLabel: context.l10n.fitPageRetryAction,
        builder: (data) => _buildList(context, data, locale),
      ),
    );
  }

  ServerSummary? _findServer(IList<ServerSummary>? data, String? serverId) {
    if (data == null || serverId == null) return null;
    for (final server in data) {
      if (server.serverId == serverId) return server;
    }
    return null;
  }

  List<String> _detailsFor(BuildContext context, ServerSummary server) {
    final l10n = context.l10n;
    return [
      "${l10n.welcomeServerMetaBuild}: ${server.gameBuild}",
      "${l10n.welcomeServerMetaVersion}: ${server.gameVersion}",
      if (server.region != null) "${l10n.welcomeServerMetaRegion}: ${server.region}",
      if (server.sync != null) "${l10n.welcomeServerMetaSync}: ${server.sync}",
      if (server.branch != null) "${l10n.welcomeServerMetaBranch}: ${server.branch}",
    ];
  }

  Widget _buildList(BuildContext context, IList<ServerSummary> servers, String locale) {
    if (servers.isEmpty) {
      return WizardContentMessage(
        message: context.l10n.welcomeServerEmpty,
        retryLabel: context.l10n.fitPageRetryAction,
        onRetry: () => ref.invalidate(serverListProvider(widget.channelName)),
      );
    }

    return WizardOptionList(
      children: [
        for (final server in servers)
          WizardOptionTile(
            title: server.displayName(locale),
            selected: _selected.contains(server.serverId),
            onTap: () => _toggle(server.serverId),
          ),
      ],
    );
  }
}
