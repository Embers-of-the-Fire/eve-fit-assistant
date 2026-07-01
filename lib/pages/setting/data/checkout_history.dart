import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/data/proto/checkout_reflog.pb.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_meta.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_registry.dart";
import "package:eve_fit_assistant/storage/repo/models/snapshot_meta.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fpdart/fpdart.dart";
import "package:intl/intl.dart";

@RoutePage(name: "CheckoutHistoryRoute")
class CheckoutHistoryPage extends ConsumerStatefulWidget {
  const CheckoutHistoryPage({required this.checkoutId, super.key});

  final String checkoutId;

  @override
  ConsumerState<CheckoutHistoryPage> createState() => _CheckoutHistoryPageState();
}

class _CheckoutHistoryPageState extends ConsumerState<CheckoutHistoryPage> {
  CheckoutRegistryEntry? _entry;
  CheckoutMeta? _meta;
  CheckoutReflog? _reflog;
  final Map<String, ResourceSnapshotMeta?> _metaCache = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final registry = ref.read(checkoutRegistryServiceProvider).readRegistry();
    _entry = registry
        .flatMap((r) => Option.fromNullable(r.checkouts[widget.checkoutId]))
        .toNullable();
    _meta = ref.read(checkoutServiceProvider).readCheckoutMeta(widget.checkoutId).toNullable();
    _reflog = ref.read(checkoutServiceProvider).readCheckoutReflog(widget.checkoutId).toNullable();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entry = _entry;
    final meta = _meta;

    if (entry == null) {
      return Layout(
        title: l10n.checkoutHistoryPageTitle,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.checkoutHistoryNotFound),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.checkoutHistoryBack),
              ),
            ],
          ),
        ),
      );
    }

    final displayName = _displayName(entry);
    final currentHash = entry.resourceSnapshotHash;
    final reflog = _reflog;
    final entries = reflog?.entries ?? <CheckoutReflog_Entry>[];
    final transitionCount = entries.length;

    return Layout(
      title: l10n.checkoutHistoryPageTitleName(name: displayName),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            l10n: l10n,
            entry: entry,
            currentHash: currentHash,
            transitionCount: transitionCount,
          ),
          if (meta != null) _buildCheckoutMeta(l10n, meta),
          const Divider(height: 1),
          Expanded(
            child: transitionCount == 0
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.checkoutHistoryEmpty,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: transitionCount,
                    itemBuilder: (context, index) {
                      final reverseIndex = transitionCount - 1 - index;
                      final transition = entries[reverseIndex];
                      final ordinal = reverseIndex + 1;
                      return _HistoryRow(
                        ordinal: ordinal,
                        transition: transition,
                        currentHash: currentHash,
                        isInitial: transition.from.isEmpty,
                        metaCache: _metaCache,
                        onRevert: () => _revert(transition.to),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader({
    required AppLocalizations l10n,
    required CheckoutRegistryEntry entry,
    required String currentHash,
    required int transitionCount,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.checkoutHistoryHeaderServer(serverId: entry.serverId),
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.checkoutHistoryHeaderChannel(channel: entry.channel),
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.checkoutHistoryHeaderCurrentHash(hash: _truncate(currentHash)),
          style: const TextStyle(fontFamily: "monospace", fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.checkoutHistoryHeaderTransitionCount(count: transitionCount),
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _buildCheckoutMeta(AppLocalizations l10n, CheckoutMeta meta) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (meta.gameBuild.isNotEmpty || meta.gameVersion.isNotEmpty)
          Text("${meta.gameBuild} / ${meta.gameVersion}", style: const TextStyle(fontSize: 12)),
        if (meta.region.isNotEmpty)
          Text(
            "${l10n.checkoutHistoryRegion}: ${meta.region}",
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
          ),
        if (meta.sync.isNotEmpty)
          Text(
            "${l10n.checkoutHistorySync}: ${meta.sync}",
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
          ),
        if (meta.branch.isNotEmpty)
          Text(
            "${l10n.checkoutHistoryBranch}: ${meta.branch}",
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
          ),
      ],
    ),
  );

  Future<void> _revert(String targetSnapshotHash) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.checkoutHistoryRevertTitle,
      content: Text(l10n.checkoutHistoryRevertConfirm(hash: _truncate(targetSnapshotHash))),
    );
    if (!confirmed) return;

    try {
      final result = await ref
          .read(checkoutServiceProvider)
          .revertCheckoutTo(widget.checkoutId, targetSnapshotHash);
      if (result.isNone()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.checkoutHistoryRevertFailed(message: "Unknown error")),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final activeId = ref.read(activeCheckoutIdProvider);
      if (activeId.toNullable() == widget.checkoutId) {
        await ref.read(repoStateProvider.notifier).initialize();
      }

      if (mounted) {
        setState(_loadData);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.checkoutHistoryRevertSuccess)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.checkoutHistoryRevertFailed(message: e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _displayName(CheckoutRegistryEntry entry) {
    final nameMap = entry.name.unlock;
    final locale = Localizations.localeOf(context).languageCode;
    return nameMap[locale] ?? nameMap["en"] ?? entry.serverId;
  }

  String _truncate(String hash) => hash.length > 12 ? "${hash.substring(0, 12)}..." : hash;
}

class _HistoryRow extends ConsumerStatefulWidget {
  const _HistoryRow({
    required this.ordinal,
    required this.transition,
    required this.currentHash,
    required this.isInitial,
    required this.metaCache,
    required this.onRevert,
  });

  final int ordinal;
  final CheckoutReflog_Entry transition;
  final String currentHash;
  final bool isInitial;
  final Map<String, ResourceSnapshotMeta?> metaCache;
  final VoidCallback onRevert;

  @override
  ConsumerState<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends ConsumerState<_HistoryRow> {
  bool _expanded = false;
  bool _loadingMeta = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMeta());
  }

  Future<void> _loadMeta() async {
    final hash = widget.transition.to;
    if (widget.metaCache.containsKey(hash)) return;
    if (hash.isEmpty) {
      widget.metaCache[hash] = null;
      return;
    }
    setState(() => _loadingMeta = true);
    final meta = ref.read(assetStoreProvider).readResourceSnapshotMetaSync(hash);
    widget.metaCache[hash] = meta.toNullable();
    if (mounted) setState(() => _loadingMeta = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isCurrent = widget.transition.to == widget.currentHash;
    final meta = widget.metaCache[widget.transition.to];

    return Semantics(
      label: l10n.checkoutHistoryRowSemantic(
        ordinal: widget.ordinal,
        fromHash: widget.transition.from.isEmpty
            ? l10n.checkoutHistoryInitialFrom
            : widget.transition.from,
        toHash: widget.transition.to,
        timestamp: _formatTime(widget.transition.timestamp),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "#${widget.ordinal}",
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTime(widget.transition.timestamp),
                      style: TextStyle(color: theme.hintColor, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "${widget.transition.from.isEmpty ? "—" : _truncate(widget.transition.from)} → ${_truncate(widget.transition.to)}",
                        style: const TextStyle(fontFamily: "monospace", fontSize: 12),
                      ),
                    ),
                    if (!isCurrent)
                      IconButton(
                        tooltip: l10n.checkoutHistoryRevertTooltip,
                        icon: const Icon(Icons.undo, size: 20),
                        onPressed: widget.onRevert,
                      ),
                  ],
                ),
                if (meta != null) ...[
                  const SizedBox(height: 8),
                  _buildMetaBlock(l10n, meta, theme),
                ] else if (_loadingMeta) ...[
                  const SizedBox(height: 8),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ] else if (widget.metaCache.containsKey(widget.transition.to)) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.checkoutHistoryMetaUnavailable,
                    style: TextStyle(color: theme.hintColor, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (isCurrent) _badge(l10n.checkoutHistoryCurrentBadge, Colors.green),
                    if (widget.isInitial) _badge(l10n.checkoutHistoryInitialBadge, theme.hintColor),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 12),
                  _buildExpandedDetails(l10n, theme, meta),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaBlock(AppLocalizations l10n, ResourceSnapshotMeta meta, ThemeData theme) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (meta.gameBuild.isNotEmpty || meta.gameVersion.isNotEmpty)
            Text("${meta.gameBuild} / ${meta.gameVersion}", style: const TextStyle(fontSize: 12)),
          Text(
            l10n.checkoutHistoryResourceCount(count: meta.resourceCount),
            style: TextStyle(color: theme.hintColor, fontSize: 12),
          ),
          if (_expanded && meta.author.isNotEmpty)
            Text(
              "${l10n.checkoutHistoryAuthor}: ${meta.author}",
              style: TextStyle(color: theme.hintColor, fontSize: 12),
            ),
          if (_expanded && meta.description.isNotEmpty)
            Text(
              "${l10n.checkoutHistoryDescription}: ${meta.description}",
              style: TextStyle(color: theme.hintColor, fontSize: 12),
            ),
        ],
      );

  Widget _buildExpandedDetails(
    AppLocalizations l10n,
    ThemeData theme,
    ResourceSnapshotMeta? meta,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _detailRow(
        l10n.checkoutHistoryFromHash,
        widget.transition.from.isEmpty ? "—" : widget.transition.from,
      ),
      _detailRow(l10n.checkoutHistoryToHash, widget.transition.to),
      if (meta != null) ...[
        if (meta.gameBuild.isNotEmpty) _detailRow(l10n.checkoutHistoryBuild, meta.gameBuild),
        if (meta.gameVersion.isNotEmpty) _detailRow(l10n.checkoutHistoryVersion, meta.gameVersion),
        if (meta.author.isNotEmpty) _detailRow(l10n.checkoutHistoryAuthor, meta.author),
        if (meta.description.isNotEmpty)
          _detailRow(l10n.checkoutHistoryDescription, meta.description),
        _detailRow(l10n.checkoutHistoryResourceCountLabel, meta.resourceCount.toString()),
        if (meta.createdAt.isNotEmpty) _detailRow(l10n.checkoutHistoryCreatedAt, meta.createdAt),
      ],
    ],
  );

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontFamily: "monospace", fontSize: 12)),
        ),
      ],
    ),
  );

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
    ),
  );

  String _truncate(String hash) => hash.length > 12 ? "${hash.substring(0, 12)}..." : hash;

  String _formatTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat("yyyy-MM-dd HH:mm").format(dt.toLocal());
  }
}
