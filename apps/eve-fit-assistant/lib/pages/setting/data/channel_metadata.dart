import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/data/proto/generation_pointer.pb.dart";
import "package:eve_fit_assistant/data/proto/generation_resources.pb.dart";
import "package:eve_fit_assistant/data/proto/release_index.pb.dart";
import "package:eve_fit_assistant/data/proto/server_index.pb.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_head_meta.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_registry.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

@RoutePage(name: "ChannelMetadataRoute")
class ChannelMetadataPage extends ConsumerStatefulWidget {
  const ChannelMetadataPage({super.key});

  @override
  ConsumerState<ChannelMetadataPage> createState() => _ChannelMetadataPageState();
}

class _ChannelMetadataPageState extends ConsumerState<ChannelMetadataPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  ChannelRegistry? _channelRegistry;
  ChannelHeadMeta? _headMeta;
  ServerIndex? _serverIndex;
  GenerationResources? _genResources;
  GenerationPointer? _releasePointer;
  ReleaseIndex? _releaseIndex;
  bool _loadingRelease = false;

  String? _selectedChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    unawaited(_readAll());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _activeChannel => ref.read(appSettingServiceProvider).remoteContent.channel;

  String get _currentChannel => _selectedChannel ?? _activeChannel;

  Future<void> _readAll() async {
    final channelService = ref.read(channelServiceProvider);
    final registry = await channelService.readLocalChannelRegistry();
    final headMeta = await channelService.readHeadMeta(_currentChannel);
    final serverIndex = await channelService.readServerIndex(_currentChannel);
    final genResources = await channelService.readGenerationResources(_currentChannel);
    final releasePointer = await channelService.readReleasePointer(_currentChannel);
    if (!mounted) return;
    setState(() {
      _channelRegistry = registry.toNullable();
      _headMeta = headMeta.toNullable();
      _serverIndex = serverIndex.toNullable();
      _genResources = genResources.toNullable();
      _releasePointer = releasePointer.toNullable();
    });
  }

  Future<void> _switchChannel(String channelName) async {
    final channelService = ref.read(channelServiceProvider);
    final headMeta = await channelService.readHeadMeta(channelName);
    final serverIndex = await channelService.readServerIndex(channelName);
    final genResources = await channelService.readGenerationResources(channelName);
    final releasePointer = await channelService.readReleasePointer(channelName);
    if (!mounted) return;
    setState(() {
      _selectedChannel = channelName;
      _headMeta = headMeta.toNullable();
      _serverIndex = serverIndex.toNullable();
      _genResources = genResources.toNullable();
      _releasePointer = releasePointer.toNullable();
      _releaseIndex = null;
    });
  }

  List<String> get _availableChannels {
    if (_channelRegistry == null) return [_activeChannel];
    return _channelRegistry!.channels.keys.toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Layout(
      title: l10n.channelMetadataPageTitle,
      actions: [
        if (_availableChannels.length > 1)
          PopupMenuButton<String>(
            icon: const Icon(Icons.swap_horiz),
            tooltip: l10n.channelMetadataSwitchChannel,
            onSelected: _switchChannel,
            itemBuilder: (ctx) => _availableChannels
                .map((name) => PopupMenuItem<String>(value: name, child: Text(name)))
                .toList(),
          ),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: [
          Tab(text: l10n.channelMetadataTabOverview),
          Tab(text: l10n.channelMetadataTabServers),
          Tab(text: l10n.channelMetadataTabResources),
          Tab(text: l10n.channelMetadataTabReleases),
        ],
      ),
      child: _channelRegistry == null
          ? Center(child: Text(l10n.channelMetadataNoData))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(l10n),
                _buildServersTab(l10n),
                _buildResourcesTab(l10n),
                _buildReleasesTab(l10n),
              ],
            ),
    );
  }

  // ── Tab 1: Overview ──────────────────────────────────────────────────────────

  Widget _buildOverviewTab(AppLocalizations l10n) {
    final head = _headMeta;
    final hash = head?.generationHash;
    final updatedAt = head?.updatedAt;
    final label = head?.label.unlock.entries.map((e) => "${e.value} (${e.key})").join(", ");
    final channels = _availableChannels.join(", ");

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _infoRow(l10n.channelMetadataFieldActiveChannel, _currentChannel),
        if (hash != null) _infoRow(l10n.channelMetadataFieldGeneration, _truncate(hash)),
        if (updatedAt != null) _infoRow(l10n.channelMetadataFieldSynced, updatedAt),
        if (label != null && label.isNotEmpty) _infoRow(l10n.channelMetadataFieldLabel, label),
        _infoRow(l10n.channelMetadataFieldChannels, channels),
        if (head == null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              l10n.channelMetadataNotSynced,
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
            ),
          ),
      ],
    );
  }

  // ── Tab 2: Servers ───────────────────────────────────────────────────────────

  Widget _buildServersTab(AppLocalizations l10n) {
    if (_serverIndex == null) {
      return Center(child: Text(l10n.channelMetadataNoServers));
    }

    final servers = _serverIndex!.servers;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Text(
          l10n.channelMetadataServerCount(count: servers.length),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        ...servers.map((s) {
          final displayName = s.name["zh"] ?? s.name["en"] ?? s.serverId;
          final parts = <String>[s.serverId, displayName, s.gameBuild, s.gameVersion];
          if (s.hasRegion()) parts.add(s.region);
          if (s.hasSync()) parts.add(s.sync);
          if (s.hasBranch()) parts.add(s.branch);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              parts.join("  "),
              style: const TextStyle(fontFamily: "monospace", fontSize: 12),
            ),
          );
        }),
      ],
    );
  }

  // ── Tab 3: Resources ─────────────────────────────────────────────────────────

  Widget _buildResourcesTab(AppLocalizations l10n) {
    if (_genResources == null) {
      return Center(child: Text(l10n.channelMetadataNoResources));
    }

    final entries = _genResources!.entries;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        ...entries.map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              "${e.serverId}  ${l10n.channelMetadataHashArrow}  ${_truncate(e.snapshotHash)}",
              style: const TextStyle(fontFamily: "monospace", fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.channelMetadataEntryCount(count: entries.length),
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
        ),
      ],
    );
  }

  // ── Tab 4: Releases ─────────────────────────────────────────────────────────

  Widget _buildReleasesTab(AppLocalizations l10n) {
    if (_releasePointer == null) {
      return Center(child: Text(l10n.channelMetadataNoReleaseData));
    }
    if (_releasePointer!.snapshotHash.isEmpty) {
      return Center(child: Text(l10n.channelMetadataNoReleaseAvailable));
    }

    return _releaseIndex != null
        ? _buildReleaseIndexContent(l10n)
        : _loadingRelease
        ? const Center(child: CircularProgressIndicator())
        : _buildLazyLoadColumn(
            l10n.channelMetadataLoadRelease,
            _loadingRelease,
            _loadReleaseIndex,
            extra: Text(
              "${l10n.channelMetadataFieldPointerHash}: ${_truncate(_releasePointer!.snapshotHash)}",
              style: const TextStyle(fontFamily: "monospace", fontSize: 12),
            ),
          );
  }

  Widget _buildReleaseIndexContent(AppLocalizations l10n) {
    final index = _releaseIndex!;
    final hasAndroid = index.hasAndroid();
    final android = hasAndroid ? index.android : null;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Text(
          "Release: v${index.version}",
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        if (hasAndroid && android != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              "General: ${android.general.identifier}",
              style: const TextStyle(fontFamily: "monospace", fontSize: 11),
            ),
          ),
          if (android.hasArmv7())
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                "Armv7:  ${android.armv7.identifier}",
                style: const TextStyle(fontFamily: "monospace", fontSize: 11),
              ),
            ),
          if (android.hasArm64())
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                "Arm64:  ${android.arm64.identifier}",
                style: const TextStyle(fontFamily: "monospace", fontSize: 11),
              ),
            ),
          if (android.hasX64())
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                "x64:    ${android.x64.identifier}",
                style: const TextStyle(fontFamily: "monospace", fontSize: 11),
              ),
            ),
        ],
        const SizedBox(height: 12),
        _loadButton(l10n.channelMetadataReload, _loadingRelease, _loadReleaseIndex),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            "$label:",
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );

  Widget _buildLazyLoadColumn(String label, bool loading, VoidCallback onTap, {Widget? extra}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (extra != null) ...[extra, const SizedBox(height: 12)],
            _loadButton(label, loading, onTap),
          ],
        ),
      );

  Widget _loadButton(String label, bool loading, VoidCallback onTap) => SizedBox(
    height: 36,
    child: OutlinedButton(
      onPressed: loading ? null : onTap,
      child: loading
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(label),
    ),
  );

  String _truncate(String hash) => hash.length > 12 ? "${hash.substring(0, 12)}..." : hash;

  // ── Lazy fetch ───────────────────────────────────────────────────────────────

  Future<void> _loadReleaseIndex() async {
    if (_releasePointer == null || _releasePointer!.snapshotHash.isEmpty) return;
    setState(() => _loadingRelease = true);

    final remoteCatalog = ref.read(remoteCatalogServiceProvider);
    final result = await remoteCatalog.fetchReleaseIndex(_releasePointer!.snapshotHash);

    if (mounted) {
      setState(() => _loadingRelease = false);
      if (result.isRight()) {
        _releaseIndex = ReleaseIndex.fromBuffer(result.getRight().toNullable()!);
      } else {
        final err = result.getLeft().toNullable()!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${context.l10n.channelMetadataLoadFailed}: ${err is CatalogNetworkError ? err.message : err.toString()}",
            ),
          ),
        );
      }
      setState(() {});
    }
  }
}
