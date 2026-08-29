import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:efa_platform_client/efa_platform_client.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/constant/links.dart";
import "package:eve_fit_assistant/features/platform/providers.dart";
import "package:eve_fit_assistant/pages/platform/common.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

@RoutePage()
class PlatformFeedPage extends ConsumerStatefulWidget {
  const PlatformFeedPage({super.key});

  @override
  ConsumerState<PlatformFeedPage> createState() => _PlatformFeedPageState();
}

class _PlatformFeedPageState extends ConsumerState<PlatformFeedPage> {
  /// The popular-ship chip currently filtering the feed; null shows all.
  TopShip? _activeShip;

  PlatformFeedFilter get _filter => PlatformFeedFilter(shipTypeId: _activeShip?.shipTypeId);

  Future<void> _refresh() async {
    ref.invalidate(platformStatsProvider);
    final provider = platformFeedProvider(_filter);
    // If the initial load is already in flight, await it instead of
    // invalidating (which would supersede the request with a duplicate).
    final current = ref.read(provider);
    if (current.isLoading && !current.hasValue) {
      await ref.read(provider.future).then((_) => null).catchError((Object _) {});
      return;
    }
    ref.invalidate(provider);
    // Errors are intentionally swallowed — the provider surfaces them via
    // its AsyncValue.
    await ref.read(provider.future).then((_) => null).catchError((Object _) {});
  }

  void _selectShip(TopShip ship) => setState(() {
    _activeShip = _activeShip?.shipTypeId == ship.shipTypeId ? null : ship;
  });

  void _clearFilter() => setState(() => _activeShip = null);

  Future<void> _loadMore() async {
    try {
      await ref.read(platformFeedProvider(_filter).notifier).loadMore();
    } on Object {
      if (mounted) showPlatformLoadMoreError(context);
    }
  }

  /// The platform only accepts fit uploads from the app; the button opens the
  /// manual page that explains publishing. Platforms without the in-app
  /// manual (web) open the online manual site instead.
  void _openUploadManual() {
    if (kIsWeb) {
      unawaited(openWebManualPage(context, docPath: publishingManualDocPath));
    } else {
      unawaited(context.router.pushPath("/manual/$publishingManualDocPath"));
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(platformFeedProvider(_filter));

    return Layout(
      title: context.l10n.platformFeedTitle,
      child: feedAsync.when(
        skipLoadingOnReload: true,
        data: (feed) => RefreshIndicator(
          onRefresh: _refresh,
          child: _PlatformFeedBody(
            feed: feed,
            activeShip: _activeShip,
            onSelectShip: _selectShip,
            onClearFilter: _clearFilter,
            onLoadMore: _loadMore,
            onUpload: _openUploadManual,
          ),
        ),
        loading: () => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: 4,
            itemBuilder: (context, index) => const PlatformPostCardSkeleton(),
          ),
        ),
        error: (error, _) =>
            PlatformErrorView(onRetry: () => ref.invalidate(platformFeedProvider(_filter))),
      ),
    );
  }
}

class _PlatformFeedBody extends ConsumerWidget {
  const _PlatformFeedBody({
    required this.feed,
    required this.activeShip,
    required this.onSelectShip,
    required this.onClearFilter,
    required this.onLoadMore,
    required this.onUpload,
  });

  final PlatformFeedState feed;
  final TopShip? activeShip;
  final ValueChanged<TopShip> onSelectShip;
  final VoidCallback onClearFilter;
  final VoidCallback onLoadMore;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(platformStatsProvider);
    final stats = statsAsync.value;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      children: [
        Row(
          children: [
            if (stats != null) Expanded(child: _PlatformStatsRow(stats: stats)) else const Spacer(),
            const SizedBox(width: 8),
            _PlatformUploadCard(onUpload: onUpload),
          ],
        ),
        if (stats != null) ...[
          if (stats.topShips.isNotEmpty) ...[
            const SizedBox(height: 16),
            _PlatformPopularShips(
              topShips: stats.topShips,
              activeShip: activeShip,
              onSelectShip: onSelectShip,
            ),
          ],
          const SizedBox(height: 16),
        ],
        if (activeShip != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PlatformActiveFilter(ship: activeShip!, onClear: onClearFilter),
          ),
        if (feed.posts.isEmpty)
          _PlatformFeedEmpty(filtered: activeShip != null)
        else ...[
          for (final post in feed.posts) PlatformPostCard(post: post),
          PlatformLoadMoreFooter(
            nextCursor: feed.nextCursor,
            isLoadingMore: feed.isLoadingMore,
            onLoadMore: onLoadMore,
          ),
        ],
      ],
    );
  }
}

/// The platform-wide totals row (shared fits, ships, new this week).
class _PlatformStatsRow extends StatelessWidget {
  const _PlatformStatsRow({required this.stats});

  final PlatformStats stats;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _PlatformStatCard(value: stats.totalPosts, label: context.l10n.platformStatsFits),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _PlatformStatCard(
          value: stats.distinctShips,
          label: context.l10n.platformStatsShips,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _PlatformStatCard(value: stats.postsLast7d, label: context.l10n.platformStatsWeek),
      ),
    ],
  );
}

/// The upload entry card at the right end of the stats row; opens the manual
/// page that explains publishing a fit.
class _PlatformUploadCard extends StatelessWidget {
  const _PlatformUploadCard({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    return Tooltip(
      message: context.l10n.platformFeedUploadAction,
      child: Card(
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainer,
        child: InkWell(
          onTap: onUpload,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Icon(Icons.upload_outlined, size: 32, color: colorScheme.primary),
          ),
        ),
      ),
    );
  }
}

class _PlatformStatCard extends StatelessWidget {
  const _PlatformStatCard({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("$value", style: context.theme.textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              label,
              style: context.theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// The popular-ships filter chips plus the entry into the full ship
/// directory.
class _PlatformPopularShips extends StatelessWidget {
  const _PlatformPopularShips({
    required this.topShips,
    required this.activeShip,
    required this.onSelectShip,
  });

  final List<TopShip> topShips;
  final TopShip? activeShip;
  final ValueChanged<TopShip> onSelectShip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.platformPopularShips,
                style: context.theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            InkWell(
              onTap: () => context.router.push(const PlatformShipsRoute()),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  context.l10n.platformShipsBrowseAll,
                  style: context.theme.textTheme.labelMedium?.copyWith(color: colorScheme.primary),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final ship in topShips)
              ChoiceChip(
                label: Text("${ship.shipName} ×${ship.postCount}"),
                selected: activeShip?.shipTypeId == ship.shipTypeId,
                onSelected: (_) => onSelectShip(ship),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ],
    );
  }
}

/// The "filtered by ship" indicator above the feed with a clear action.
class _PlatformActiveFilter extends StatelessWidget {
  const _PlatformActiveFilter({required this.ship, required this.onClear});

  final TopShip ship;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            context.l10n.platformFeedFilteredBy(ship: ship.shipName),
            style: context.theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          onPressed: onClear,
          icon: const Icon(Icons.close, size: 18),
          tooltip: context.l10n.platformFeedClearFilter,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _PlatformFeedEmpty extends StatelessWidget {
  const _PlatformFeedEmpty({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 96),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.groups_outlined, size: 56, color: context.theme.colorScheme.outline),
        const SizedBox(height: 12),
        Text(
          filtered ? context.l10n.platformFeedEmptyFiltered : context.l10n.platformFeedEmpty,
          style: context.theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
