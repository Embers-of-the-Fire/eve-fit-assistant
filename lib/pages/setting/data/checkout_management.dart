import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/data/proto/generation_resources.pb.dart";
import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/data/proto/server_index.pb.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
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

@RoutePage(name: "CheckoutManagementRoute")
class CheckoutManagementPage extends ConsumerStatefulWidget {
  const CheckoutManagementPage({super.key});

  @override
  ConsumerState<CheckoutManagementPage> createState() => _CheckoutManagementPageState();
}

class _CheckoutManagementPageState extends ConsumerState<CheckoutManagementPage> {
  String get _activeChannel => ref.read(appSettingServiceProvider).remoteContent.channel;

  IMap<String, CheckoutRegistryEntry> _resolveCheckouts(CheckoutRegistry? registry) {
    if (registry == null) return const IMap.empty();
    return registry.checkouts;
  }

  String? _resolveActiveId(CheckoutRegistry? registry) => registry?.activeCheckoutId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final registrySnapshot = ref.watch(activeCheckoutWatchProvider);
    final registry = registrySnapshot.value;
    final checkouts = _resolveCheckouts(registry);
    final activeId = _resolveActiveId(registry);

    return Layout(
      title: l10n.checkoutManagementPageTitle,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateCheckoutSheet,
        icon: const Icon(Icons.add),
        label: Text(l10n.checkoutCreateButton),
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
    final ri = ref.read(assetStoreProvider).readResourceIndexSync(entry.resourceSnapshotHash);
    final fileCount = ri.match(() => -1, (r) => r.entries.length);
    final totalSize = ri.match(
      () => -1,
      (r) => r.entries.fold<int>(0, (sum, e) => sum + e.size.toInt()),
    );
    final isOnlyActive = checkouts.length <= 1 && isActive;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.checkoutStatusActive,
                      style: TextStyle(color: Colors.green.shade800, fontSize: 11),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).hintColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.checkoutStatusInactive,
                      style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _checkoutField(l10n.checkoutFieldChannel, entry.channel),
            _checkoutField(l10n.checkoutFieldServerId, entry.serverId),
            _checkoutField(l10n.checkoutFieldSnapshotHash, _truncate(entry.resourceSnapshotHash)),
            if (fileCount >= 0) _checkoutField(l10n.checkoutFieldFileCount, fileCount.toString()),
            if (totalSize >= 0) _checkoutField(l10n.checkoutFieldTotalSize, _formatSize(totalSize)),
            if (fileCount < 0) _checkoutField(l10n.checkoutFieldFileCount, l10n.checkoutNA),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isActive)
                  TextButton.icon(
                    onPressed: () => _activateCheckout(checkoutId, displayName),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text(l10n.checkoutActivate),
                  ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: isOnlyActive
                      ? null
                      : () => _deleteCheckout(checkoutId, displayName, isActive),
                  icon: Icon(Icons.delete_outline, size: 18, color: isActive ? Colors.red : null),
                  label: Text(
                    l10n.checkoutDelete,
                    style: TextStyle(color: isActive ? Colors.red : null),
                  ),
                ),
              ],
            ),
          ],
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
    final registry = ref.read(activeCheckoutWatchProvider).value;
    return _resolveCheckouts(registry);
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
    _readLocalGenData();
  }

  void _readLocalGenData() {
    final channelService = ref.read(channelServiceProvider);
    _genResources = channelService.readGenerationResources(widget.activeChannel).toNullable();
    _serverIndex = channelService.readServerIndex(widget.activeChannel).toNullable();
    _generationHash = channelService.localGenerationHash(widget.activeChannel);
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
      _readLocalGenData();
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runDownload());
  }

  Future<void> _runDownload() async {
    final l10n = context.l10n;

    try {
      setState(() => _status = l10n.checkoutCreateProgressFetchingIndex);

      // Fetch ResourceIndex
      final remoteCatalog = ref.read(remoteCatalogServiceProvider);
      final indexResult = await remoteCatalog.fetchResourceIndex(widget.snapshotHash);
      if (indexResult.isLeft()) {
        final err = indexResult.getLeft().toNullable()!;
        setState(() {
          _failed = true;
          _error = err is CatalogNetworkError
              ? err.message
              : l10n.checkoutCreateProgressIndexFailed;
        });
        return;
      }
      final resourceIndex = ResourceIndex.fromBuffer(indexResult.getRight().toNullable()!);
      final totalEntries = resourceIndex.entries.length;

      setState(() {
        _status = l10n.checkoutCreateProgressDownloading(count: totalEntries);
        _progress = 0;
      });

      // Download blobs
      var downloaded = 0;
      final failedBlobs = <String>[];
      final assetStore = ref.read(assetStoreProvider);

      for (final entry in resourceIndex.entries) {
        final identHash = RepoHash.hashIdent(entry.resourceId);

        // Skip if already exists
        if (assetStore.blobExistsSync(identHash, entry.contentHash)) {
          downloaded++;
          if (mounted) {
            setState(() {
              _progress = totalEntries > 0 ? downloaded / totalEntries : null;
              _status = l10n.checkoutCreateProgressDownloading2(
                current: downloaded,
                total: totalEntries,
              );
            });
          }
          continue;
        }

        final blobResult = await remoteCatalog.fetchBlob(identHash, entry.contentHash);
        if (blobResult.isRight()) {
          assetStore.writeBlobSync(identHash, blobResult.getRight().toNullable()!);
        } else {
          failedBlobs.add(entry.resourceId);
        }

        downloaded++;
        if (mounted) {
          setState(() {
            _progress = totalEntries > 0 ? downloaded / totalEntries : null;
            _status = l10n.checkoutCreateProgressDownloading2(
              current: downloaded,
              total: totalEntries,
            );
          });
        }
      }

      // Write snapshot metadata locally
      setState(() => _status = l10n.checkoutCreateProgressFinalizing);
      final metaResult = await remoteCatalog.fetchResourceSnapshotMeta(widget.snapshotHash);
      if (metaResult.isRight()) {
        final meta = metaResult.getRight().toNullable()!;
        assetStore.writeResourceSnapshotSync(meta: meta, resourceIndex: resourceIndex);
      } else {
        // Write basic metadata anyway
        final basicMeta = ResourceSnapshotMeta(
          schemaVersion: 1,
          serverId: widget.serverId,
          gameBuild: "",
          gameVersion: "",
          resourceCount: totalEntries,
          createdAt: DateTime.now().toUtc().toIso8601String(),
        );
        assetStore.writeResourceSnapshotSync(meta: basicMeta, resourceIndex: resourceIndex);
      }

      // Create checkout entry
      setState(() => _status = l10n.checkoutCreateProgressCreatingCheckout);

      final checkoutService = ref.read(checkoutServiceProvider);
      final nameMap = IMap({"zh": widget.serverDisplayName, "en": widget.serverDisplayName});
      final result = await checkoutService.createCheckout(
        channel: widget.channel,
        serverId: widget.serverId,
        name: nameMap,
        generationHash: widget.generationHash,
        resourceSnapshotHash: widget.snapshotHash,
      );

      if (result.isNone()) {
        setState(() {
          _failed = true;
          _error = l10n.checkoutCreateProgressCheckoutFailed;
        });
        return;
      }

      // Auto-activate via registry (setActive: true is default in addCheckout)
      await ref.read(repoStateProvider.notifier).initialize();

      setState(() {
        _complete = true;
        _progress = 1;
        _status = l10n.checkoutCreateProgressComplete;
      });

      if (mounted) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.checkoutCreateSuccess)));
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(
        _complete
            ? l10n.checkoutCreateProgressTitleComplete
            : _failed
            ? l10n.checkoutCreateProgressTitleFailed
            : l10n.checkoutCreateProgressTitle(server: widget.serverDisplayName),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_status, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (_progress != null && _progress! < 1 && !_failed)
            LinearProgressIndicator(value: _progress)
          else if (_progress == null && !_failed && !_complete)
            const LinearProgressIndicator()
          else if (_complete)
            const Icon(Icons.check_circle, color: Colors.green, size: 48)
          else
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: (_complete || _failed)
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  _complete ? MaterialLocalizations.of(context).closeButtonLabel : l10n.ok,
                ),
              ),
            ]
          : null,
    );
  }
}
