import "dart:async";

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
  final void Function(IList<ServerSummary> selectedServers) onContinue;
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
        if (_activeId == serverId) {
          _activeId = _selected.isEmpty ? null : _selected.first;
        }
      } else {
        _selected.add(serverId);
        _activeId = serverId;
      }
    });
  }

  void _onContinuePressed(int count, IList<ServerSummary> selectedServers) {
    final l10n = context.l10n;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.welcomeDownloadConfirmTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.welcomeDownloadConfirmMessage(count: count)),
              const SizedBox(height: 8),
              Text(
                l10n.welcomeDownloadConfirmWarning,
                style: TextStyle(fontSize: 13, color: Theme.of(ctx).hintColor),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onSkip();
              },
              child: Text(l10n.welcomeDownloadSkipButton),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onContinue(selectedServers);
              },
              child: Text(l10n.welcomeDownloadConfirmButton),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider).name;
    final selectionData = ref.watch(serverSelectionDataProvider(widget.channelName));

    final focusedServer = _findServer(selectionData.value?.servers, _activeId);
    final totalSize = _computeTotal(selectionData.value);
    final downloadCount = _computeCount(selectionData.value);

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
      primaryEnabled: _activeId != null && downloadCount != null,
      onPrimary: () {
        final data = selectionData.value;
        if (data == null) return;
        final selected = data.servers.where((s) => _selected.contains(s.serverId)).toIList();
        _onContinuePressed(downloadCount!, selected);
      },
      secondaryActions: [
        WizardAction(label: context.l10n.welcomeBackButton, onPressed: widget.onBack),
        WizardAction(label: context.l10n.welcomeSkipButton, onPressed: widget.onSkip),
      ],
      content: WizardAsyncContent(
        value: selectionData,
        onRetry: () => ref.invalidate(serverSelectionDataProvider(widget.channelName)),
        errorMessage: context.l10n.welcomeServerError,
        retryLabel: context.l10n.fitPageRetryAction,
        builder: (data) => _buildList(context, data, locale, totalSize),
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

  String? _computeTotal(ServerSelectionData? data) {
    if (data == null || _selected.isEmpty) return null;
    final union = <String, int>{};
    for (final serverId in _selected) {
      final blobs = data.blobsForServer[serverId];
      if (blobs == null) continue;
      for (final entry in blobs.entries) {
        union[entry.key] = entry.value;
      }
    }
    if (union.isEmpty) return null;
    return _formatSize(union.values.fold<int>(0, (a, b) => a + b));
  }

  int? _computeCount(ServerSelectionData? data) {
    if (data == null || _selected.isEmpty) return null;
    final union = <String>{};
    for (final serverId in _selected) {
      final blobs = data.blobsForServer[serverId];
      if (blobs == null) continue;
      union.addAll(blobs.keys);
    }
    return union.isEmpty ? null : union.length;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  List<String> _detailsFor(BuildContext context, ServerSummary server) {
    final l10n = context.l10n;
    return [
      "${l10n.welcomeServerMetaBuild}: ${server.gameBuild}",
      "${l10n.welcomeServerMetaVersion}: ${server.gameVersion}",
      "${l10n.welcomeServerMetaRegion}: ${server.region ?? "—"}",
      "${l10n.welcomeServerMetaSync}: ${server.sync ?? "—"}",
      "${l10n.welcomeServerMetaBranch}: ${server.branch ?? "—"}",
    ];
  }

  Widget _buildList(
    BuildContext context,
    ServerSelectionData data,
    String locale,
    String? totalSize,
  ) {
    final servers = data.servers;
    if (servers.isEmpty) {
      return WizardContentMessage(
        message: context.l10n.welcomeServerEmpty,
        retryLabel: context.l10n.fitPageRetryAction,
        onRetry: () => ref.invalidate(serverSelectionDataProvider(widget.channelName)),
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
        Padding(
          padding: EdgeInsets.only(left: WizardTokens.of(context).cardRadius),
          child: SizedBox(
            width: double.infinity,
            child: Text(
              totalSize != null ? context.l10n.welcomeServerDownloadSize(size: totalSize) : "—",
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
