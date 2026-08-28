import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:efa_platform_client/efa_platform_client.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/features/platform/providers.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

@RoutePage()
class PlatformFeedPage extends ConsumerWidget {
  const PlatformFeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(platformFeedProvider);

    Future<void> refresh() async {
      // If the initial load is already in flight, await it instead of
      // invalidating (which would supersede the request with a duplicate).
      final current = ref.read(platformFeedProvider);
      if (current.isLoading && !current.hasValue) {
        await ref.read(platformFeedProvider.future).then((_) => null).catchError((Object _) {});
        return;
      }
      ref.invalidate(platformFeedProvider);
      // Errors are intentionally swallowed — the provider surfaces them via
      // its AsyncValue.
      await ref.read(platformFeedProvider.future).then((_) => null).catchError((Object _) {});
    }

    return Layout(
      title: context.l10n.platformFeedTitle,
      child: feedAsync.when(
        skipLoadingOnReload: true,
        data: (feed) => RefreshIndicator(
          onRefresh: refresh,
          child: feed.posts.isEmpty ? const _PlatformFeedEmpty() : _PlatformPostList(feed: feed),
        ),
        loading: () => RefreshIndicator(
          onRefresh: refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: 4,
            itemBuilder: (context, index) => const _PlatformPostCardSkeleton(),
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 56, color: context.theme.colorScheme.error),
                const SizedBox(height: 12),
                Text(
                  context.l10n.platformFeedLoadError,
                  style: context.theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(platformFeedProvider),
                  child: Text(context.l10n.announcementBodyLoadRetry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatformFeedEmpty extends StatelessWidget {
  const _PlatformFeedEmpty();

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
            Icon(Icons.groups_outlined, size: 56, color: context.theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              context.l10n.platformFeedEmpty,
              style: context.theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ],
  );
}

class _PlatformPostList extends ConsumerWidget {
  const _PlatformPostList({required this.feed});

  final PlatformFeedState feed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasMore = feed.nextCursor != null;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: feed.posts.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= feed.posts.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Center(
              child: feed.isLoadingMore
                  ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())
                  : OutlinedButton(
                      onPressed: () async {
                        try {
                          await ref.read(platformFeedProvider.notifier).loadMore();
                        } on Object {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.l10n.platformFeedLoadError)),
                            );
                          }
                        }
                      },
                      child: Text(context.l10n.platformFeedLoadMore),
                    ),
            ),
          );
        }
        return _PlatformPostCard(post: feed.posts[index]);
      },
    );
  }
}

class _PlatformPostCard extends StatelessWidget {
  const _PlatformPostCard({required this.post});

  final PostSummary post;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    final createdAt = DateTime.tryParse(post.createdAt);
    final dateText = createdAt == null
        ? post.createdAt
        : DateFormat.yMMMMd(context.locale.toString()).format(createdAt.toLocal());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.surfaceContainer,
      child: InkWell(
        onTap: () => context.router.push(PlatformPostRoute(postId: post.postId)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PlatformPostBadge(label: post.shipName, icon: Icons.rocket_launch_outlined),
                  _PlatformPostBadge(label: dateText, icon: Icons.event_outlined),
                ],
              ),
              const SizedBox(height: 12),
              Text(post.fitName, style: context.theme.textTheme.titleMedium),
              if (post.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  post.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformPostBadge extends StatelessWidget {
  const _PlatformPostBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 6),
            Text(label, style: context.theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

/// Skeleton placeholder that mimics the layout of [_PlatformPostCard] while
/// the feed is loading for the first time.
class _PlatformPostCardSkeleton extends StatelessWidget {
  const _PlatformPostCardSkeleton();

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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SkeletonBox(width: 80, height: 26, color: skeletonColor),
                _SkeletonBox(width: 100, height: 26, color: skeletonColor),
              ],
            ),
            const SizedBox(height: 12),
            _SkeletonBox(width: 200, height: 20, color: skeletonColor),
            const SizedBox(height: 8),
            _SkeletonBox(width: double.infinity, height: 14, color: skeletonColor),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.width, required this.height, required this.color});

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
  );
}
