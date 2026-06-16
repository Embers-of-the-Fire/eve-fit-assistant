// THIS FILE DOES NOT USE LOCALIZATION.
// All strings are hardcoded English — this is a developer-facing diagnostic
// page, not an end-user screen.

import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/config_list.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/data/proto/announcement_index.pb.dart";
import "package:eve_fit_assistant/data/proto/generation_pointer.pb.dart";
import "package:eve_fit_assistant/data/proto/generation_resources.pb.dart";
import "package:eve_fit_assistant/data/proto/release_index.pb.dart";
import "package:eve_fit_assistant/data/proto/server_index.pb.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_head_meta.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_registry.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

@RoutePage(name: "ChannelOverviewRoute")
class ChannelOverviewPage extends ConsumerStatefulWidget {
  const ChannelOverviewPage({super.key});

  @override
  ConsumerState<ChannelOverviewPage> createState() => _ChannelOverviewPageState();
}

class _ChannelOverviewPageState extends ConsumerState<ChannelOverviewPage> {
  ChannelRegistry? _channelRegistry;
  ChannelHeadMeta? _headMeta;
  ServerIndex? _serverIndex;
  GenerationResources? _genResources;
  GenerationPointer? _releasePointer;
  GenerationPointer? _announcementPointer;
  ReleaseIndex? _releaseIndex;
  AnnouncementIndex? _announcementIndex;
  bool _loadingRelease = false;
  bool _loadingAnnouncement = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _readAll();
  }

  void _readAll() {
    final channelService = ref.read(channelServiceProvider);

    _channelRegistry = channelService.readLocalChannelRegistry().toNullable();

    _headMeta = channelService.readHeadMeta(_activeChannel).toNullable();
    _serverIndex = channelService.readServerIndex(_activeChannel).toNullable();
    _genResources = channelService.readGenerationResources(_activeChannel).toNullable();
    _releasePointer = channelService.readReleasePointer(_activeChannel).toNullable();
    _announcementPointer = channelService.readAnnouncementPointer(_activeChannel).toNullable();
  }

  String get _activeChannel => ref.read(appSettingServiceProvider).remoteContent.channel;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => Layout(
    title: "Channel Overview",
    child: ConfigListView(
      children: [
        const ConfigListTile.space(20),
        const ConfigListTile.title("Channel"),
        _buildChannelInfo(),
        ConfigListTile.title(
          _serverIndex != null ? "Servers (${_serverIndex!.servers.length})" : "Servers",
        ),
        _buildServerCatalog(),
        const ConfigListTile.title("Generation Resources"),
        _buildGenerationResources(),
        const ConfigListTile.title("Release Info"),
        _buildReleaseInfo(),
        const ConfigListTile.title("Announcement Info"),
        _buildAnnouncementInfo(),
        const ConfigListTile.title("Actions"),
        ConfigListTile.item(
          icon: const Icon(Icons.refresh),
          title: "Refresh from Remote",
          subtitle: _refreshing ? "Syncing..." : null,
          onTap: _refreshing ? null : _runRefresh,
        ),
      ],
    ),
  );

  // ── Channel Info ───────────────────────────────────────────────────────────

  ConfigListTile _buildChannelInfo() {
    if (_channelRegistry == null) {
      return _placeholder("No channel data — sync has not run.");
    }

    final chanNames = _channelRegistry!.channels.keys.join(", ");
    final head = _headMeta;
    final hash = head?.generationHash;
    final updatedAt = head?.updatedAt;
    final label = head?.label.unlock.entries.map((e) => "${e.value} (${e.key})").join(", ");

    return ConfigListTile.custom(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field("Active", _activeChannel),
            if (hash != null) _field("Generation", _truncate(hash)),
            if (updatedAt != null) _field("Synced", updatedAt),
            if (label != null && label.isNotEmpty) _field("Label", label),
            _field("Channels", chanNames),
          ],
        ),
      ),
    );
  }

  // ── Server Catalog ─────────────────────────────────────────────────────────

  ConfigListTile _buildServerCatalog() {
    if (_serverIndex == null) {
      return _placeholder("No server catalog — run sync or create a checkout.");
    }

    return ConfigListTile.custom(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _serverIndex!.servers.map((s) {
            final name = s.name["en"] ?? s.serverId;
            final parts = <String>[s.serverId, name, s.gameBuild, s.gameVersion];
            if (s.hasRegion()) parts.add(s.region);
            if (s.hasSync()) parts.add(s.sync);
            if (s.hasBranch()) parts.add(s.branch);
            return Text(
              parts.join("  "),
              style: const TextStyle(fontFamily: "monospace", fontSize: 12),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Generation Resources ───────────────────────────────────────────────────

  ConfigListTile _buildGenerationResources() {
    if (_genResources == null) {
      return _placeholder("No generation resources available.");
    }

    final entries = _genResources!.entries;
    return ConfigListTile.custom(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...entries.map(
              (e) => Text(
                "${e.serverId} -> ${_truncate(e.snapshotHash)}",
                style: const TextStyle(fontFamily: "monospace", fontSize: 12),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "${entries.length} entries total",
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ── Release Info ───────────────────────────────────────────────────────────

  ConfigListTile _buildReleaseInfo() {
    if (_releasePointer == null) {
      return _placeholder("No release pointer — generation data not synced.");
    }

    return ConfigListTile.custom(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field("Pointer hash", _truncate(_releasePointer!.snapshotHash)),
            const SizedBox(height: 8),
            if (_releaseIndex != null)
              _buildReleaseIndexContent()
            else if (_loadingRelease)
              const Center(
                child: Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
              )
            else ...[
              Text(
                "Tap 'Load Release Index' to fetch release catalog.",
                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
              ),
              const SizedBox(height: 8),
              _loadButton("Load Release Index", _loadingRelease, _loadReleaseIndex),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReleaseIndexContent() {
    final entries = _releaseIndex!.entries;
    if (entries.isEmpty) {
      return const Text("No releases in index.", style: TextStyle(fontSize: 12));
    }

    String? latestVersion;
    for (final e in entries) {
      if (e.offerings.contains("android")) {
        if (latestVersion == null || _compareSemver(e.version, latestVersion) > 0) {
          latestVersion = e.version;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "${entries.length} releases",
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        if (latestVersion != null) ...[
          const SizedBox(height: 4),
          Text(
            "Latest (android): $latestVersion",
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green, fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
        ...entries.map(
          (e) => Text(
            "${e.id}  v${e.version}  [${e.offerings.join(", ")}]  ${_truncate(e.identHash)}",
            style: const TextStyle(fontFamily: "monospace", fontSize: 11),
          ),
        ),
        const SizedBox(height: 8),
        _loadButton("Load Release Index", _loadingRelease, _loadReleaseIndex),
      ],
    );
  }

  // ── Announcement Info ──────────────────────────────────────────────────────

  ConfigListTile _buildAnnouncementInfo() {
    if (_announcementPointer == null) {
      return _placeholder("No announcement pointer — generation data not synced.");
    }

    return ConfigListTile.custom(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field("Pointer hash", _truncate(_announcementPointer!.snapshotHash)),
            const SizedBox(height: 8),
            if (_announcementIndex != null)
              _buildAnnouncementIndexContent()
            else if (_loadingAnnouncement)
              const Center(
                child: Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
              )
            else ...[
              Text(
                "Tap 'Load Announcement Index' to fetch announcement catalog.",
                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
              ),
              const SizedBox(height: 8),
              _loadButton("Load Announcement Index", _loadingAnnouncement, _loadAnnouncementIndex),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementIndexContent() {
    final entries = _announcementIndex!.entries;
    final versionUpdateCount = entries.where((e) => e.isVersionUpdate).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "${entries.length} announcements, $versionUpdateCount version-update",
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        const SizedBox(height: 8),
        ...entries.map((e) {
          final locales = e.contentHashes.keys.join(", ");
          final constraints = <String>[];
          if (e.hasVersionMin()) constraints.add("min=${e.versionMin}");
          if (e.hasVersionMax()) constraints.add("max=${e.versionMax}");
          final constraintStr = constraints.isNotEmpty ? " [${constraints.join(", ")}]" : "";
          final vu = e.isVersionUpdate ? " VU" : "";
          return Text(
            "${e.id}$vu  published: ${e.firstPublishedAt}  updated: ${e.updatedAt}  locales: $locales$constraintStr",
            style: const TextStyle(fontFamily: "monospace", fontSize: 11),
          );
        }),
        const SizedBox(height: 8),
        _loadButton("Load Announcement Index", _loadingAnnouncement, _loadAnnouncementIndex),
      ],
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _runRefresh() async {
    setState(() => _refreshing = true);
    _releaseIndex = null;
    _announcementIndex = null;

    final channelService = ref.read(channelServiceProvider);

    // 1. Discover channels — fetch + persist registry from remote.
    final discoverResult = await channelService.discoverChannels();
    if (discoverResult.isLeft()) {
      warning("Channel discovery failed: ${discoverResult.getLeft().toNullable()}");
      if (mounted) setState(() => _refreshing = false);
      return;
    }

    // 2. Sync generation metadata for the configured channel.
    final syncResult = await channelService.syncChannelGeneration(_activeChannel);
    if (syncResult.isLeft()) {
      warning("Generation sync failed: ${syncResult.getLeft().toNullable()}");
    }

    if (mounted) {
      setState(() {
        _refreshing = false;
        _readAll();
      });
    }
  }

  Future<void> _loadReleaseIndex() async {
    if (_releasePointer == null) return;
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
              "Failed to load release index: ${err is CatalogNetworkError ? err.message : err.toString()}",
            ),
          ),
        );
      }
      setState(() {}); // rebuild to show/update content
    }
  }

  Future<void> _loadAnnouncementIndex() async {
    if (_announcementPointer == null) return;
    setState(() => _loadingAnnouncement = true);

    final remoteCatalog = ref.read(remoteCatalogServiceProvider);
    final result = await remoteCatalog.fetchAnnouncementIndex(_announcementPointer!.snapshotHash);

    if (mounted) {
      setState(() => _loadingAnnouncement = false);
      if (result.isRight()) {
        _announcementIndex = AnnouncementIndex.fromBuffer(result.getRight().toNullable()!);
      } else {
        final err = result.getLeft().toNullable()!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to load announcement index: ${err is CatalogNetworkError ? err.message : err.toString()}",
            ),
          ),
        );
      }
      setState(() {});
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  ConfigListTile _placeholder(String text) => ConfigListTile.custom(
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(text, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
    ),
  );

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
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

  Widget _loadButton(String label, bool loading, VoidCallback onTap) => SizedBox(
    height: 32,
    child: OutlinedButton(
      onPressed: loading ? null : onTap,
      child: loading
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(label),
    ),
  );

  String _truncate(String hash) => hash.length > 12 ? "${hash.substring(0, 12)}..." : hash;

  int _compareSemver(String a, String b) {
    final partsA = a.split(".").map((s) => int.tryParse(s) ?? 0).toList();
    final partsB = b.split(".").map((s) => int.tryParse(s) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final va = i < partsA.length ? partsA[i] : 0;
      final vb = i < partsB.length ? partsB[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }
}
