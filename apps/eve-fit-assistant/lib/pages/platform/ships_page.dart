import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:efa_platform_client/efa_platform_client.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/features/platform/providers.dart";
import "package:eve_fit_assistant/pages/platform/common.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// The ship directory: a searchable, time-window-filtered list of the ships
/// with shared fits, matching the site's `/ships` page.
@RoutePage()
class PlatformShipsPage extends ConsumerStatefulWidget {
  const PlatformShipsPage({super.key});

  @override
  ConsumerState<PlatformShipsPage> createState() => _PlatformShipsPageState();
}

class _PlatformShipsPageState extends ConsumerState<PlatformShipsPage> {
  static const _searchDebounce = Duration(milliseconds: 300);

  final _searchController = TextEditingController();
  Timer? _searchTimer;
  String _query = "";
  PlatformTimeWindow _window = PlatformTimeWindow.all;

  PlatformShipQuery get _shipQuery => PlatformShipQuery(query: _query, window: _window);

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(_searchDebounce, () => setState(() => _query = value));
  }

  void _onWindowSelected(PlatformTimeWindow window) {
    if (window == _window) return;
    setState(() => _window = window);
  }

  Future<void> _refresh() async {
    final provider = platformShipDirectoryProvider(_shipQuery);
    final current = ref.read(provider);
    if (current.isLoading && !current.hasValue) {
      await ref.read(provider.future).then((_) => null).catchError((Object _) {});
      return;
    }
    ref.invalidate(provider);
    await ref.read(provider.future).then((_) => null).catchError((Object _) {});
  }

  Future<void> _loadMore() async {
    try {
      await ref.read(platformShipDirectoryProvider(_shipQuery).notifier).loadMore();
    } on Object {
      if (mounted) showPlatformLoadMoreError(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final directoryAsync = ref.watch(platformShipDirectoryProvider(_shipQuery));

    return Layout(
      title: context.l10n.platformShipsTitle,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: context.l10n.platformShipsSearchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
            child: PlatformWindowChips(selected: _window, onSelected: _onWindowSelected),
          ),
          Expanded(
            child: directoryAsync.when(
              skipLoadingOnReload: true,
              data: (directory) => RefreshIndicator(
                onRefresh: _refresh,
                child: directory.ships.isEmpty
                    ? const _PlatformShipsEmpty()
                    : _PlatformShipList(directory: directory, onLoadMore: _loadMore),
              ),
              loading: () => RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: 6,
                  itemBuilder: (context, index) => const _PlatformShipCardSkeleton(),
                ),
              ),
              error: (error, _) => PlatformErrorView(
                onRetry: () => ref.invalidate(platformShipDirectoryProvider(_shipQuery)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformShipsEmpty extends StatelessWidget {
  const _PlatformShipsEmpty();

  @override
  Widget build(BuildContext context) => ListView(
    // Always-scrollable so pull-to-refresh stays available on the empty state.
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 96),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rocket_launch_outlined, size: 56, color: context.theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              context.l10n.platformShipsEmpty,
              style: context.theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ],
  );
}

class _PlatformShipList extends StatelessWidget {
  const _PlatformShipList({required this.directory, required this.onLoadMore});

  final PlatformShipDirectoryState directory;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) => ListView.builder(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    itemCount: directory.ships.length + 1,
    itemBuilder: (context, index) {
      if (index >= directory.ships.length) {
        return PlatformLoadMoreFooter(
          nextCursor: directory.nextCursor,
          isLoadingMore: directory.isLoadingMore,
          onLoadMore: onLoadMore,
        );
      }
      return _PlatformShipCard(ship: directory.ships[index]);
    },
  );
}

class _PlatformShipCard extends StatelessWidget {
  const _PlatformShipCard({required this.ship});

  final ShipSummary ship;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.surfaceContainer,
      child: InkWell(
        onTap: () => context.router.push(PlatformShipRoute(shipTypeId: ship.shipTypeId)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ship.shipName, style: context.theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                "×${ship.postCount} · "
                "${context.l10n.platformShipsLastActive}: "
                "${formatPlatformDate(context, ship.lastPostAt)}",
                style: context.theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformShipCardSkeleton extends StatelessWidget {
  const _PlatformShipCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final skeletonColor = context.theme.colorScheme.surfaceContainerHighest;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: context.theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlatformSkeletonBox(width: 120, height: 20, color: skeletonColor),
            const SizedBox(height: 8),
            PlatformSkeletonBox(width: 200, height: 14, color: skeletonColor),
          ],
        ),
      ),
    );
  }
}
