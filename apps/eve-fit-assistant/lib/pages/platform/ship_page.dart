import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:efa_platform_client/efa_platform_client.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/features/platform/providers.dart";
import "package:eve_fit_assistant/pages/platform/common.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// The ship detail page: the ship's platform stats plus its shared-fit feed
/// under a time-window filter, matching the site's `/ship/[id]` page. This
/// is the static entrypoint for a ship (`efa://platform/ship/<shipTypeId>`).
@RoutePage()
class PlatformShipPage extends ConsumerStatefulWidget {
  const PlatformShipPage({@PathParam("shipTypeId") required this.shipTypeId, super.key});

  final int shipTypeId;

  @override
  ConsumerState<PlatformShipPage> createState() => _PlatformShipPageState();
}

class _PlatformShipPageState extends ConsumerState<PlatformShipPage> {
  PlatformTimeWindow _window = PlatformTimeWindow.all;

  PlatformFeedFilter get _filter =>
      PlatformFeedFilter(shipTypeId: widget.shipTypeId, window: _window);

  void _onWindowSelected(PlatformTimeWindow window) {
    if (window == _window) return;
    setState(() => _window = window);
  }

  Future<void> _refresh() async {
    ref.invalidate(platformShipProvider(widget.shipTypeId));
    final provider = platformFeedProvider(_filter);
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
      await ref.read(platformFeedProvider(_filter).notifier).loadMore();
    } on Object {
      if (mounted) showPlatformLoadMoreError(context);
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
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              _PlatformShipHeader(shipTypeId: widget.shipTypeId),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PlatformWindowChips(selected: _window, onSelected: _onWindowSelected),
              ),
              if (feed.posts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 96),
                  child: Text(
                    context.l10n.platformFeedEmptyFiltered,
                    style: context.theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                for (final post in feed.posts) PlatformPostCard(post: post),
                PlatformLoadMoreFooter(
                  nextCursor: feed.nextCursor,
                  isLoadingMore: feed.isLoadingMore,
                  onLoadMore: _loadMore,
                ),
              ],
            ],
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

/// The ship header: name, post count and first/last shared dates. A failed
/// or missing detail degrades to the "ship not found" title, matching the
/// site.
class _PlatformShipHeader extends ConsumerWidget {
  const _PlatformShipHeader({required this.shipTypeId});

  final int shipTypeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(platformShipProvider(shipTypeId));
    final colorScheme = context.theme.colorScheme;

    return switch (detailAsync) {
      AsyncData(:final value) when value != null => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value.shipName, style: context.theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              "${context.l10n.platformStatsFits}: ${value.postCount} · "
              "${context.l10n.platformShipFirstShared}: "
              "${formatPlatformDate(context, value.firstPostAt)} · "
              "${context.l10n.platformShipsLastActive}: "
              "${formatPlatformDate(context, value.lastPostAt)}",
              style: context.theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      AsyncData() || AsyncError() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          context.l10n.platformShipNotFound,
          style: context.theme.textTheme.headlineSmall,
        ),
      ),
      _ => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlatformSkeletonBox(width: 180, height: 28, color: colorScheme.surfaceContainerHighest),
            const SizedBox(height: 8),
            PlatformSkeletonBox(width: 280, height: 14, color: colorScheme.surfaceContainerHighest),
          ],
        ),
      ),
    };
  }
}
