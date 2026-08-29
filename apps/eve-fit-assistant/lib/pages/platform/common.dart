import "package:auto_route/auto_route.dart";
import "package:efa_platform_client/efa_platform_client.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:intl/intl.dart";

/// Formats an ISO-8601 timestamp from the platform API as a localized date,
/// falling back to the raw text when it cannot be parsed.
String formatPlatformDate(BuildContext context, String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  return DateFormat.yMMMMd(context.locale.toString()).format(date.toLocal());
}

/// A shared-fit post summary card; tapping it opens the post page.
class PlatformPostCard extends StatelessWidget {
  const PlatformPostCard({required this.post, super.key});

  final PostSummary post;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    final dateText = formatPlatformDate(context, post.createdAt);

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

/// Skeleton placeholder that mimics the layout of [PlatformPostCard] while
/// the feed is loading for the first time.
class PlatformPostCardSkeleton extends StatelessWidget {
  const PlatformPostCardSkeleton({super.key});

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
                PlatformSkeletonBox(width: 80, height: 26, color: skeletonColor),
                PlatformSkeletonBox(width: 100, height: 26, color: skeletonColor),
              ],
            ),
            const SizedBox(height: 12),
            PlatformSkeletonBox(width: 200, height: 20, color: skeletonColor),
            const SizedBox(height: 8),
            PlatformSkeletonBox(width: double.infinity, height: 14, color: skeletonColor),
          ],
        ),
      ),
    );
  }
}

/// A flat-color placeholder box used by the platform skeletons.
class PlatformSkeletonBox extends StatelessWidget {
  const PlatformSkeletonBox({
    required this.width,
    required this.height,
    required this.color,
    super.key,
  });

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

/// The trailing load-more control of a cursor-paginated platform list; null
/// [nextCursor] (an exhausted list) renders nothing.
class PlatformLoadMoreFooter extends StatelessWidget {
  const PlatformLoadMoreFooter({
    required this.nextCursor,
    required this.isLoadingMore,
    required this.onLoadMore,
    super.key,
  });

  final String? nextCursor;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (nextCursor == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: isLoadingMore
            ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())
            : OutlinedButton(onPressed: onLoadMore, child: Text(context.l10n.platformFeedLoadMore)),
      ),
    );
  }
}

/// Full-page error state with a retry action.
class PlatformErrorView extends StatelessWidget {
  const PlatformErrorView({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
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
          OutlinedButton(onPressed: onRetry, child: Text(context.l10n.announcementBodyLoadRetry)),
        ],
      ),
    ),
  );
}

/// The time-window filter chips shared by the ship directory and the ship
/// detail feed (24 hours / 7 days / 30 days / all time).
class PlatformWindowChips extends StatelessWidget {
  const PlatformWindowChips({required this.selected, required this.onSelected, super.key});

  final PlatformTimeWindow selected;
  final ValueChanged<PlatformTimeWindow> onSelected;

  String _label(BuildContext context, PlatformTimeWindow window) => switch (window) {
    PlatformTimeWindow.h24 => context.l10n.platformWindow24h,
    PlatformTimeWindow.d7 => context.l10n.platformWindow7d,
    PlatformTimeWindow.d30 => context.l10n.platformWindow30d,
    PlatformTimeWindow.all => context.l10n.platformWindowAll,
  };

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final window in PlatformTimeWindow.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_label(context, window)),
              selected: selected == window,
              onSelected: (_) => onSelected(window),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    ),
  );
}

/// Shows a snackbar when a load-more request fails.
void showPlatformLoadMoreError(BuildContext context) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.platformFeedLoadError)));
}
