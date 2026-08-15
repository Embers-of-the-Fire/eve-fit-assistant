import "dart:async";
import "dart:math" show min;

import "package:auto_route/auto_route.dart";
import "package:efa_proto/generation_resources.pb.dart";
import "package:efa_proto/server_index.pb.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/pages/setting/data/data_update_dialog.dart";
import "package:eve_fit_assistant/storage/repo/checkout_provisioner.dart";
import "package:eve_fit_assistant/storage/repo/data_update_status.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_registry.dart";
import "package:eve_fit_assistant/storage/repo/models/snapshot_meta.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fpdart/fpdart.dart";
import "package:intl/intl.dart";

@RoutePage(name: "CheckoutManagementRoute")
class CheckoutManagementPage extends ConsumerStatefulWidget {
  const CheckoutManagementPage({super.key});

  @override
  ConsumerState<CheckoutManagementPage> createState() => _CheckoutManagementPageState();
}

class _CheckoutManagementPageState extends ConsumerState<CheckoutManagementPage> {
  String get _activeChannel => ref.read(appSettingServiceProvider).remoteContent.channel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.watch(activeCheckoutWatchProvider);
    final registry = ref.read(checkoutRegistryServiceProvider).readRegistry();
    final checkouts = registry.match(
      () => const IMap<String, CheckoutRegistryEntry>.empty(),
      (r) => r.checkouts,
    );
    final activeId = registry.flatMap((r) => Option.fromNullable(r.activeCheckoutId)).toNullable();

    return Layout(
      title: l10n.checkoutManagementPageTitle,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateCheckoutSheet,
        icon: const Icon(Icons.inventory_2_outlined),
        label: Text(l10n.checkoutManageDataButton),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      child: checkouts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 64, color: Theme.of(context).hintColor),
                    const SizedBox(height: 16),
                    Text(l10n.checkoutNoCheckoutsTitle, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      l10n.checkoutNoCheckoutsHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
              itemCount: checkouts.length,
              itemBuilder: (context, index) {
                final entry = checkouts.entries.elementAt(index);
                return _checkoutCard(entry.key, entry.value, activeId);
              },
            ),
    );
  }

  // ── Checkout Card ────────────────────────────────────────────────────────────

  Widget _checkoutCard(String checkoutId, CheckoutRegistryEntry entry, String? activeId) {
    final l10n = context.l10n;
    final isActive = checkoutId == activeId;
    final displayName = _displayName(entry);
    final isOnlyActive = checkouts.length <= 1 && isActive;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _activeIndicator(isActive, checkoutId, displayName),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  _chip(entry.channel),
                  _chip("${l10n.checkoutFieldUpdatedAt}: ${_formatTime(entry.createdAt)}"),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.checkoutUpdateButton,
              icon: const Icon(Icons.update_outlined),
              onPressed: () => _updateCheckout(checkoutId),
            ),
            IconButton(
              tooltip: l10n.checkoutHistoryButton,
              icon: const Icon(Icons.history),
              onPressed: () => _openHistory(checkoutId),
            ),
            IconButton(
              tooltip: l10n.checkoutInfoButton,
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showInfoSheet(checkoutId, entry, isActive),
            ),
            IconButton(
              tooltip: l10n.checkoutDelete,
              icon: Icon(
                Icons.delete_outline,
                color: isActive && !isOnlyActive ? Colors.red : null,
              ),
              onPressed: isOnlyActive
                  ? null
                  : () => _deleteCheckout(checkoutId, displayName, isActive),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeIndicator(bool isActive, String checkoutId, String displayName) {
    final theme = Theme.of(context);
    final circle = Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? theme.colorScheme.primary : Colors.transparent,
        border: Border.all(color: isActive ? theme.colorScheme.primary : theme.hintColor, width: 2),
      ),
      child: isActive ? Icon(Icons.check, size: 18, color: theme.colorScheme.onPrimary) : null,
    );
    if (isActive) return circle;
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => _activateCheckout(checkoutId, displayName),
      child: circle,
    );
  }

  Widget _chip(String label) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.hintColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: theme.hintColor)),
    );
  }

  String _formatTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat("yyyy-MM-dd HH:mm").format(dt.toLocal());
  }

  Future<void> _showInfoSheet(String checkoutId, CheckoutRegistryEntry entry, bool isActive) async {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final displayName = _displayName(entry);
    final assetStore = ref.read(assetStoreProvider);
    final ri = await assetStore.readResourceIndex(entry.resourceSnapshotHash);
    if (!mounted) return;
    final fileCount = ri.match(() => -1, (r) => r.entries.length);
    final totalSize = ri.match(
      () => -1,
      (r) => r.entries.fold<int>(0, (sum, e) => sum + e.size.toInt()),
    );
    // Count blobs actually present on disk (batched), not the download
    // policy: FORCE entries whose downloads failed are not downloaded, and
    // NON_FORCE entries already lazily fetched do occupy disk.
    final split = await ri.match(() async => null, (r) async {
      var downloadedCount = 0;
      var downloadedSize = 0;
      var onDemandCount = 0;
      var onDemandSize = 0;
      const batchSize = 64;
      final entries = r.entries;
      for (var start = 0; start < entries.length; start += batchSize) {
        final batch = entries.sublist(start, min(start + batchSize, entries.length));
        final exists = await Future.wait(
          batch.map((e) => assetStore.blobExists(RepoHash.hashIdent(e.resourceId), e.contentHash)),
        );
        for (var i = 0; i < batch.length; i++) {
          final size = batch[i].size.toInt();
          if (exists[i]) {
            downloadedCount++;
            downloadedSize += size;
          } else {
            onDemandCount++;
            onDemandSize += size;
          }
        }
      }
      return (
        downloadedCount: downloadedCount,
        downloadedSize: downloadedSize,
        onDemandCount: onDemandCount,
        onDemandSize: onDemandSize,
      );
    });
    if (!mounted) return;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(displayName, style: theme.textTheme.titleLarge)),
                  _statusBadge(isActive),
                ],
              ),
              const SizedBox(height: 16),
              _checkoutField(l10n.checkoutFieldChannel, entry.channel),
              _checkoutField(l10n.checkoutFieldServerId, entry.serverId),
              _checkoutField(l10n.checkoutFieldSnapshotHash, _truncate(entry.resourceSnapshotHash)),
              _checkoutField(l10n.checkoutFieldUpdatedAt, _formatTime(entry.createdAt)),
              _checkoutField(
                l10n.checkoutFieldFileCount,
                fileCount >= 0 ? fileCount.toString() : l10n.checkoutNA,
              ),
              _checkoutField(
                l10n.checkoutFieldTotalSize,
                totalSize >= 0 ? _formatSize(totalSize) : l10n.checkoutNA,
              ),
              if (split != null) ...[
                _checkoutField(
                  l10n.storageDownloadedLabel,
                  l10n.storageDownloadedValue(
                    count: split.downloadedCount,
                    size: _formatSize(split.downloadedSize),
                  ),
                ),
                _checkoutField(
                  l10n.storageOnDemandLabel,
                  l10n.storageOnDemandValue(
                    count: split.onDemandCount,
                    size: _formatSize(split.onDemandSize),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.history, size: 18),
                  label: Text(l10n.checkoutHistoryButton),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openHistory(checkoutId);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(bool isActive) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.shade100
            : Theme.of(context).hintColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? l10n.checkoutStatusActive : l10n.checkoutStatusInactive,
        style: TextStyle(
          color: isActive ? Colors.green.shade800 : Theme.of(context).hintColor,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _checkoutField(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontFamily: "monospace", fontSize: 12)),
        ),
      ],
    ),
  );

  // ── Operations ───────────────────────────────────────────────────────────────

  IMap<String, CheckoutRegistryEntry> get checkouts {
    final registry = ref.read(checkoutRegistryServiceProvider).readRegistry();
    return registry.match(
      () => const IMap<String, CheckoutRegistryEntry>.empty(),
      (r) => r.checkouts,
    );
  }

  Future<void> _activateCheckout(String checkoutId, String displayName) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.checkoutActivateTitle,
      content: Text(l10n.checkoutActivateConfirm(name: displayName)),
    );
    if (!confirmed) return;

    try {
      await ref.read(checkoutRegistryServiceProvider).setActiveCheckout(checkoutId);
      await ref.read(repoStateProvider.notifier).initialize();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.checkoutActivateSuccess(name: displayName))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.checkoutActivateFailed(message: e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateCheckout(String checkoutId) {
    final provider = checkoutUpdateControllerProvider(checkoutId);
    ref.read(provider);
    late final ProviderSubscription<DataUpdateStatus> sub;
    sub = ref.listenManual(provider, (_, _) {}, fireImmediately: true);

    unawaited(showCheckoutDataUpdateOperationDialog(context, ref, checkoutId));

    final controller = ref.read(provider.notifier);
    unawaited(
      controller.check().then((_) async {
        sub.close();
      }),
    );
  }

  Future<void> _deleteCheckout(String checkoutId, String displayName, bool isActive) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.checkoutDeleteTitle,
      content: Text(
        isActive
            ? l10n.checkoutDeleteConfirmActive(name: displayName)
            : l10n.checkoutDeleteConfirm(name: displayName),
      ),
    );
    if (!confirmed) return;

    try {
      await ref.read(repoServiceProvider).deleteCheckout(checkoutId);
      if (mounted) {
        try {
          await ref.read(repoStateProvider.notifier).initialize();
        } catch (_) {
          // initialization may fail if no checkouts remain; the SchemaGuard handles this
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.checkoutDeleteSuccess(name: displayName))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.checkoutDeleteFailed(message: e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openHistory(String checkoutId) {
    unawaited(context.router.push(CheckoutHistoryRoute(checkoutId: checkoutId)));
  }

  // ── Create Checkout Sheet ────────────────────────────────────────────────────

  void _openCreateCheckoutSheet() {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        barrierColor: Colors.black54,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollController) => _CheckoutCreateSheet(
            scrollController: scrollController,
            activeChannel: _activeChannel,
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _displayName(CheckoutRegistryEntry entry) {
    final nameMap = entry.name.unlock;
    final locale = Localizations.localeOf(context).languageCode;
    return nameMap[locale] ?? nameMap["en"] ?? entry.serverId;
  }

  String _truncate(String hash) => hash.length > 12 ? "${hash.substring(0, 12)}..." : hash;

  String _formatSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }
}

// ── Create Checkout Sheet ──────────────────────────────────────────────────────

class _CheckoutCreateSheet extends ConsumerStatefulWidget {
  const _CheckoutCreateSheet({required this.scrollController, required this.activeChannel});

  final ScrollController scrollController;
  final String activeChannel;

  @override
  ConsumerState<_CheckoutCreateSheet> createState() => _CheckoutCreateSheetState();
}

class _CheckoutCreateSheetState extends ConsumerState<_CheckoutCreateSheet> {
  GenerationResources? _genResources;
  ServerIndex? _serverIndex;
  String? _generationHash;
  bool _syncing = false;
  String? _syncError;

  // Selected server
  String? _selectedServerId;
  String? _selectedSnapshotHash;
  ResourceSnapshotMeta? _selectedSnapshotMeta;
  bool _loadingMeta = false;
  String? _metaError;

  // Metadata cache: snapshotHash -> ResourceSnapshotMeta?
  final Map<String, ResourceSnapshotMeta?> _metaCache = {};

  @override
  void initState() {
    super.initState();
    unawaited(
      _readLocalGenData().then((_) {
        if (mounted) setState(() {});
      }),
    );
  }

  Future<void> _readLocalGenData() async {
    final channelService = ref.read(channelServiceProvider);
    _genResources = (await channelService.readGenerationResources(
      widget.activeChannel,
    )).toNullable();
    _serverIndex = (await channelService.readServerIndex(widget.activeChannel)).toNullable();
    _generationHash = await channelService.localGenerationHash(widget.activeChannel);
  }

  bool get _hasGenData => _genResources != null && _genResources!.entries.isNotEmpty;

  ServerIndex_Entry? _findServerInfo(String serverId) {
    if (_serverIndex == null) return null;
    for (final s in _serverIndex!.servers) {
      if (s.serverId == serverId) return s;
    }
    return null;
  }

  String _serverDisplayName(String serverId) {
    final si = _findServerInfo(serverId);
    if (si == null) return serverId;
    final locale = Localizations.localeOf(context).languageCode;
    return si.name[locale] ?? si.name["en"] ?? serverId;
  }

  Future<void> _syncGeneration() async {
    setState(() {
      _syncing = true;
      _syncError = null;
    });
    try {
      final channelService = ref.read(channelServiceProvider);
      final syncResult = await channelService.syncChannelGeneration(widget.activeChannel);
      if (syncResult.isLeft()) {
        setState(() => _syncError = syncResult.getLeft().toNullable());
        return;
      }
      final discoverResult = await channelService.discoverChannels();
      if (discoverResult.isLeft()) {
        setState(() => _syncError = discoverResult.getLeft().toNullable());
        return;
      }
      await _readLocalGenData();
      setState(() {});
    } finally {
      setState(() => _syncing = false);
    }
  }

  Future<void> _selectServer(String serverId, String snapshotHash) async {
    setState(() {
      _selectedServerId = serverId;
      _selectedSnapshotHash = snapshotHash;
      _selectedSnapshotMeta = null;
      _metaError = null;
    });

    // Check cache first
    if (_metaCache.containsKey(snapshotHash)) {
      setState(() => _selectedSnapshotMeta = _metaCache[snapshotHash]);
      return;
    }

    setState(() => _loadingMeta = true);
    try {
      final remoteCatalog = ref.read(remoteCatalogServiceProvider);
      final result = await remoteCatalog.fetchResourceSnapshotMeta(snapshotHash);
      if (result.isRight()) {
        final meta = result.getRight().toNullable()!;
        _metaCache[snapshotHash] = meta;
        setState(() => _selectedSnapshotMeta = meta);
      } else {
        final err = result.getLeft().toNullable()!;
        setState(() => _metaError = err is CatalogNetworkError ? err.message : err.toString());
      }
    } catch (e) {
      setState(() => _metaError = e.toString());
    } finally {
      setState(() => _loadingMeta = false);
    }
  }

  void _confirmCreate() {
    if (_selectedServerId == null || _selectedSnapshotHash == null || _generationHash == null) {
      return;
    }

    final channel = Channel.tryParse(widget.activeChannel) ?? Channel.defaultChannel;

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _CreateProgressDialog(
          channel: channel,
          channelName: widget.activeChannel,
          serverId: _selectedServerId!,
          snapshotHash: _selectedSnapshotHash!,
          generationHash: _generationHash!,
          serverDisplayName: _serverDisplayName(_selectedServerId!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.hintColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: Text(l10n.checkoutCreateTitle, style: theme.textTheme.titleLarge)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(),
          // Content
          Expanded(
            child: _hasGenData ? _buildServerSelection(l10n, theme) : _buildSyncPrompt(l10n, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncPrompt(AppLocalizations l10n, ThemeData theme) => ListView(
    controller: widget.scrollController,
    padding: const EdgeInsets.all(16),
    children: [
      if (_syncError != null) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_syncError!, style: TextStyle(color: Colors.red.shade800)),
        ),
        const SizedBox(height: 12),
      ],
      Text(l10n.checkoutCreateNeedSync, style: TextStyle(color: theme.hintColor)),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton.icon(
          onPressed: _syncing ? null : _syncGeneration,
          icon: _syncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_download),
          label: Text(_syncing ? l10n.checkoutCreateSyncing : l10n.checkoutCreateSyncNow),
        ),
      ),
    ],
  );

  Widget _buildServerSelection(AppLocalizations l10n, ThemeData theme) {
    final entries = _genResources!.entries;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.checkoutCreateSelectServer(count: entries.length),
            style: TextStyle(color: theme.hintColor, fontSize: 13),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: entries.length,
            itemBuilder: (ctx, index) {
              final e = entries[index];
              final serverId = e.serverId;
              final snapshotHash = e.snapshotHash;
              final isSelected = _selectedServerId == serverId;
              final si = _findServerInfo(serverId);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                    width: isSelected ? 2 : 0,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _selectServer(serverId, snapshotHash),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _serverDisplayName(serverId),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                            Text(
                              _truncateHash(snapshotHash),
                              style: TextStyle(
                                fontFamily: "monospace",
                                fontSize: 11,
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${l10n.checkoutCreateFieldId}: $serverId",
                          style: TextStyle(
                            fontFamily: "monospace",
                            fontSize: 12,
                            color: theme.hintColor,
                          ),
                        ),
                        if (si != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            "${si.gameBuild} / ${si.gameVersion}",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                        // Expanded metadata
                        if (isSelected) ...[
                          const SizedBox(height: 8),
                          if (_loadingMeta)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          else if (_metaError != null)
                            Text(
                              "${l10n.checkoutCreateMetaFailed}: $_metaError",
                              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                            )
                          else if (_selectedSnapshotMeta != null) ...[
                            _metaField(
                              l10n.checkoutCreateFieldAuthor,
                              _selectedSnapshotMeta!.author,
                            ),
                            _metaField(
                              l10n.checkoutCreateFieldDescription,
                              _selectedSnapshotMeta!.description,
                            ),
                            _metaField(
                              l10n.checkoutCreateFieldResourceCount,
                              _selectedSnapshotMeta!.resourceCount.toString(),
                            ),
                            _metaField(
                              l10n.checkoutCreateFieldCreatedAt,
                              _selectedSnapshotMeta!.createdAt,
                            ),
                            if (_selectedSnapshotMeta!.gameRegion.isNotEmpty)
                              _metaField(
                                l10n.checkoutCreateFieldRegion,
                                _selectedSnapshotMeta!.gameRegion,
                              ),
                            if (_selectedSnapshotMeta!.gameSync.isNotEmpty)
                              _metaField(
                                l10n.checkoutCreateFieldSync,
                                _selectedSnapshotMeta!.gameSync,
                              ),
                            if (_selectedSnapshotMeta!.gameBranch.isNotEmpty)
                              _metaField(
                                l10n.checkoutCreateFieldBranch,
                                _selectedSnapshotMeta!.gameBranch,
                              ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Confirm button
        if (_selectedServerId != null)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loadingMeta ? null : _confirmCreate,
                  child: Text(
                    _selectedSnapshotMeta != null
                        ? l10n.checkoutCreateConfirmWithCount(
                            count: _selectedSnapshotMeta!.resourceCount,
                          )
                        : l10n.checkoutCreateConfirm,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _metaField(String label, String value) => value.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  label,
                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
                ),
              ),
              Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
            ],
          ),
        );

  String _truncateHash(String hash) => hash.length > 12 ? "${hash.substring(0, 12)}..." : hash;
}

// ── Create Progress Dialog ─────────────────────────────────────────────────────

class _CreateProgressDialog extends ConsumerStatefulWidget {
  const _CreateProgressDialog({
    required this.channel,
    required this.channelName,
    required this.serverId,
    required this.snapshotHash,
    required this.generationHash,
    required this.serverDisplayName,
  });

  final Channel channel;
  final String channelName;
  final String serverId;
  final String snapshotHash;
  final String generationHash;
  final String serverDisplayName;

  @override
  ConsumerState<_CreateProgressDialog> createState() => _CreateProgressDialogState();
}

class _CreateProgressDialogState extends ConsumerState<_CreateProgressDialog> {
  String _status = "";
  double? _progress;
  bool _failed = false;
  String? _error;
  bool _complete = false;
  bool _partial = false;
  CheckoutProvisioner? _provisioner;
  StreamSubscription<ProvisionerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startProvisioning());
  }

  @override
  void dispose() {
    unawaited(_stateSub?.cancel());
    _provisioner
      ?..cancel()
      ..dispose();
    super.dispose();
  }

  /// Runs the shared policy-aware provisioning pipeline: NON_FORCE resources
  /// are skipped (fetched lazily on first access) and the index is validated
  /// for the current platform.
  void _startProvisioning() {
    final provisioner = CheckoutProvisioner(
      remoteCatalog: ref.read(remoteCatalogServiceProvider),
      assetStore: ref.read(assetStoreProvider),
      checkoutService: ref.read(checkoutServiceProvider),
    );
    _provisioner = provisioner;
    _stateSub = provisioner.state.listen(_onProvisionerState);
    provisioner.configure(
      channel: widget.channel,
      channelName: widget.channelName,
      serverId: widget.serverId,
      name: IMap({"zh": widget.serverDisplayName, "en": widget.serverDisplayName}),
      generationHash: widget.generationHash,
      resourceSnapshotHash: widget.snapshotHash,
    );
    unawaited(provisioner.execute());
  }

  Future<void> _onProvisionerState(ProvisionerState state) async {
    if (!mounted) return;
    final l10n = context.l10n;
    switch (state) {
      case ProvisionerPreparing():
        setState(() => _status = l10n.checkoutCreateProgressFetchingIndex);
      case ProvisionerDownloading(:final downloaded, :final total, :final progress):
        setState(() {
          _status = l10n.checkoutCreateProgressDownloading2(current: downloaded, total: total);
          _progress = progress;
        });
      case ProvisionerFinalizing():
        setState(() => _status = l10n.checkoutCreateProgressFinalizing);
      case ProvisionerComplete(:final failedBlobs):
        // The checkout was already created and auto-activated by the registry
        // (setActive: true is default in addCheckout), so it must be loaded
        // into memory even when some blobs failed — otherwise the next app
        // start silently activates a half-provisioned checkout. Failed blobs
        // can be re-fetched later via verify & repair.
        await ref.read(repoStateProvider.notifier).initialize();
        if (!mounted) return;
        if (failedBlobs.isNotEmpty) {
          setState(() {
            _partial = true;
            _progress = 1;
            _status = l10n.checkoutCreateProgressComplete;
            _error = l10n.checkoutCreateProgressBlobsFailed(count: failedBlobs.length);
          });
          return;
        }
        setState(() {
          _complete = true;
          _progress = 1;
          _status = l10n.checkoutCreateProgressComplete;
        });
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.checkoutCreateSuccess)));
          }
        });
      case ProvisionerFatal(:final message):
        setState(() {
          _failed = true;
          _error = message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(
        _complete
            ? l10n.checkoutCreateProgressTitleComplete
            : _partial
            ? l10n.checkoutCreateProgressTitlePartial
            : _failed
            ? l10n.checkoutCreateProgressTitleFailed
            : l10n.checkoutCreateProgressTitle(server: widget.serverDisplayName),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_status, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (_progress != null && _progress! < 1 && !_failed && !_partial)
            LinearProgressIndicator(value: _progress)
          else if (_progress == null && !_failed && !_complete && !_partial)
            const LinearProgressIndicator()
          else if (_complete)
            const Icon(Icons.check_circle, color: Colors.green, size: 48)
          else if (_partial)
            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700, size: 48)
          else
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                color: _partial ? Colors.amber.shade900 : Colors.red.shade700,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (_partial) ...[
            const SizedBox(height: 12),
            Text(
              l10n.checkoutCreateProgressPartialHint,
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: (_complete || _failed || _partial)
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  _complete || _partial
                      ? MaterialLocalizations.of(context).closeButtonLabel
                      : l10n.ok,
                ),
              ),
            ]
          : null,
    );
  }
}
