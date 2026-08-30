import "package:auto_route/auto_route.dart";
import "package:efa_acl/efa_acl.dart";
import "package:efa_fit/efa_fit.dart";
import "package:efa_fit_snapshot/efa_fit_snapshot.dart";
import "package:efa_platform_client/efa_platform_client.dart";
import "package:eve_fit_assistant/components/icon/efa_icon_resolver.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/account/providers.dart";
import "package:eve_fit_assistant/features/fit_link/providers.dart";
import "package:eve_fit_assistant/features/platform/providers.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

@RoutePage()
class PlatformPostPage extends ConsumerWidget {
  const PlatformPostPage({@PathParam("postId") required this.postId, super.key});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(platformPostProvider(postId));
    return Layout(
      title: context.l10n.platformFeedTitle,
      child: postAsync.when(
        data: (post) {
          if (post == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.find_in_page_outlined,
                      size: 56,
                      color: context.theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.platformPostNotFound,
                      style: context.theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return _PlatformPostContent(post: post, postId: postId);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
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
                  onPressed: () => ref.invalidate(platformPostProvider(postId)),
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

class _PlatformPostContent extends ConsumerWidget {
  const _PlatformPostContent({required this.post, required this.postId});

  final PlatformPostDetail post;
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.symmetric(vertical: 10),
    children: [
      FitSnapshotView(
        snapshot: post.snapshot,
        iconResolver: ref.watch(appEfaIconResolverProvider),
        headerAction: _OpenInAppButton(fitHash: post.record.fitHash),
      ),
      const Divider(height: 32),
      _CommentSection(postId: postId, commentCount: post.record.commentCount),
    ],
  );
}

/// The open-in-app action of a platform post: imports the registered fit
/// addressed by [fitHash] into local storage and opens it, mirroring the
/// site's post header (`FitShareLanding` forwards to the same registered
/// link for browsers).
class _OpenInAppButton extends ConsumerStatefulWidget {
  const _OpenInAppButton({required this.fitHash});

  final String fitHash;

  @override
  ConsumerState<_OpenInAppButton> createState() => _OpenInAppButtonState();
}

class _OpenInAppButtonState extends ConsumerState<_OpenInAppButton> {
  bool _busy = false;

  void _showError(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openInApp() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final metadata = await ref.read(fitLinkImporterProvider).importRegistered(widget.fitHash);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.fitImportSuccess(fitName: metadata.name))),
      );
      await context.router.push(FitRoute(fitId: metadata.fitId));
    } on FitLinkNotFoundException {
      debug("Open-in-app: registered fit ${widget.fitHash} not found on the platform");
      if (mounted) _showError(context.l10n.fitImportUnknownError);
    } on Object catch (e, st) {
      warning("Open-in-app import failed for ${widget.fitHash}: $e", stackTrace: st);
      if (mounted) _showError(context.l10n.fitImportUnknownError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
    onPressed: _busy ? null : _openInApp,
    icon: _busy
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.rocket_launch_outlined),
    label: Text(context.l10n.platformPostOpenInApp),
  );
}

class _CommentSection extends ConsumerWidget {
  const _CommentSection({required this.postId, required this.commentCount});

  final String postId;
  final int commentCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(platformCommentsProvider(postId));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.platformCommentsTitle(count: commentCount),
            style: context.theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...commentsAsync.when(
            skipLoadingOnReload: true,
            data: (state) => [
              if (state.comments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    context.l10n.platformCommentsEmpty,
                    style: context.theme.textTheme.bodyMedium?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final comment in state.comments) _CommentTile(comment: comment),
              if (state.nextCursor != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: state.isLoadingMore
                        ? const CircularProgressIndicator()
                        : OutlinedButton(
                            onPressed: () async {
                              try {
                                await ref
                                    .read(platformCommentsProvider(postId).notifier)
                                    .loadMore();
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
                ),
            ],
            loading: () => [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (error, _) => [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  context.l10n.platformFeedLoadError,
                  style: context.theme.textTheme.bodyMedium?.copyWith(
                    color: context.theme.colorScheme.error,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () => ref.invalidate(platformCommentsProvider(postId)),
                child: Text(context.l10n.announcementBodyLoadRetry),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CommentComposer(postId: postId),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    final createdAt = DateTime.tryParse(comment.createdAt);
    final dateText = createdAt == null
        ? comment.createdAt
        : DateFormat.yMMMMd(context.locale.toString()).add_Hm().format(createdAt.toLocal());

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (comment.authorDeleted)
                  Text(
                    context.l10n.platformCommentDeletedAuthor,
                    style: context.theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const Spacer(),
                Text(
                  dateText,
                  style: context.theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Bodies are raw markdown served verbatim; flutter_markdown_plus
            // never injects raw HTML, so rendering here is safe.
            MarkdownBody(data: comment.body),
          ],
        ),
      ),
    );
  }
}

class _CommentComposer extends ConsumerStatefulWidget {
  const _CommentComposer({required this.postId});

  final String postId;

  @override
  ConsumerState<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends ConsumerState<_CommentComposer> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(platformCommentsProvider(widget.postId).notifier).submit(body);
      if (!mounted) return;
      _controller.clear();
    } on PlatformApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == "forbidden"
                ? context.l10n.platformCommentForbidden
                : context.l10n.platformCommentSubmitError,
          ),
        ),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.platformCommentSubmitError)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(platformIdentityProvider).value;
    final acl = ref.watch(accountAclProvider).value;

    if (identity == null) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.login_rounded),
        title: Text(context.l10n.platformCommentSignInPrompt),
        trailing: TextButton(
          onPressed: () => context.router.push(const AccountLoginRoute()),
          child: Text(context.l10n.platformCommentSignInAction),
        ),
      );
    }
    if (acl == null || !acl.canCommentCreate()) {
      return const SizedBox.shrink();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 6,
            enabled: !_busy,
            decoration: InputDecoration(
              hintText: context.l10n.platformCommentComposerHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _busy ? null : _submit,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded),
          tooltip: context.l10n.platformCommentSend,
        ),
      ],
    );
  }
}
