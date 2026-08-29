import "package:efa_platform_client/efa_platform_client.dart";
import "package:efa_proto/fit_snapshot.pb.dart";
import "package:eve_fit_assistant/features/account/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "providers.g.dart";

/// The platform post-feed list state: the accumulated pages plus the cursor
/// for the next page (null when the feed is exhausted).
class PlatformFeedState {
  const PlatformFeedState({
    required this.posts,
    required this.nextCursor,
    this.isLoadingMore = false,
  });

  final List<PostSummary> posts;
  final String? nextCursor;
  final bool isLoadingMore;
}

/// The platform post feed: a cursor-paginated, descending list of shared-fit
/// posts. Pull-to-refresh re-runs [build] via `ref.invalidate`.
@riverpodSingleton
class PlatformFeed extends _$PlatformFeed {
  @override
  Future<PlatformFeedState> build() async {
    final session = await ref.watch(platformSessionProvider.future);
    final locale = ref.watch(localeProvider).name;
    final page = await session.listPosts(locale: locale);
    return PlatformFeedState(posts: page.posts, nextCursor: page.nextCursor);
  }

  /// Appends the next page; a no-op when the feed is exhausted or a page is
  /// already in flight. Errors restore the previous state and rethrow so the
  /// UI can surface a message.
  Future<void> loadMore() async {
    final current = state.value;
    final cursor = current?.nextCursor;
    if (current == null || cursor == null || current.isLoadingMore) return;
    state = AsyncData(
      PlatformFeedState(posts: current.posts, nextCursor: cursor, isLoadingMore: true),
    );
    try {
      final session = await ref.read(platformSessionProvider.future);
      final locale = ref.read(localeProvider).name;
      final page = await session.listPosts(cursor: cursor, locale: locale);
      state = AsyncData(
        PlatformFeedState(posts: [...current.posts, ...page.posts], nextCursor: page.nextCursor),
      );
    } on Object {
      state = AsyncData(current);
      rethrow;
    }
  }
}

/// The platform post detail: the post record plus its stored snapshot.
class PlatformPostDetail {
  const PlatformPostDetail({required this.record, required this.snapshot});

  final PostRecord record;
  final FitSnapshot snapshot;
}

/// The post record and snapshot behind [postId]; null when the post does not
/// exist (or its snapshot is gone).
@riverpod
Future<PlatformPostDetail?> platformPost(Ref ref, String postId) async {
  final session = await ref.watch(platformSessionProvider.future);
  final record = await session.getPost(postId);
  if (record == null) return null;
  final snapshot = await session.getPostSnapshot(postId);
  if (snapshot == null) return null;
  return PlatformPostDetail(record: record, snapshot: snapshot);
}

/// The comment-list state of a post: the accumulated ascending pages plus
/// the cursor for the next page (null when the list is exhausted).
class PlatformCommentState {
  const PlatformCommentState({
    required this.comments,
    required this.nextCursor,
    this.isLoadingMore = false,
  });

  final List<Comment> comments;
  final String? nextCursor;
  final bool isLoadingMore;
}

/// The discussion comments under a post: a flat, ascending (oldest-first)
/// cursor-paginated list. Comment deletion and editing are deferred; only
/// listing and creation are supported here.
@riverpod
class PlatformComments extends _$PlatformComments {
  /// Incremented on every state mutation so overlapping async work can reject
  /// stale writes: [loadMore] and [submit] may run concurrently, and the one
  /// finishing last must not replace a newer state with its stale snapshot.
  int _generation = 0;

  @override
  Future<PlatformCommentState> build(String postId) async {
    final session = await ref.watch(platformSessionProvider.future);
    final page = await session.listComments(postId);
    return PlatformCommentState(comments: page.comments, nextCursor: page.nextCursor);
  }

  /// Appends the next page; a no-op when the list is exhausted or a page is
  /// already in flight. If [submit] mutated the state while the page was in
  /// flight, the stale page is discarded instead of overwriting the newer
  /// state. Errors restore the previous state (unless it is stale) and
  /// rethrow.
  Future<void> loadMore() async {
    final current = state.value;
    final cursor = current?.nextCursor;
    if (current == null || cursor == null || current.isLoadingMore) return;
    final generation = _generation;
    state = AsyncData(
      PlatformCommentState(comments: current.comments, nextCursor: cursor, isLoadingMore: true),
    );
    try {
      final session = await ref.read(platformSessionProvider.future);
      final page = await session.listComments(postId, cursor: cursor);
      if (generation != _generation) return;
      _generation++;
      state = AsyncData(
        PlatformCommentState(
          comments: [...current.comments, ...page.comments],
          nextCursor: page.nextCursor,
        ),
      );
    } on Object {
      if (generation == _generation) state = AsyncData(current);
      rethrow;
    }
  }

  /// Tail of the in-flight [submit] chain. Each submission waits for the
  /// previous one to settle so two concurrent creations cannot snapshot the
  /// same state and have the later write drop the earlier comment.
  Future<void> _submitTail = Future<void>.value();

  /// Creates a comment authored by the signed-in account. New comments land
  /// at the end of the ascending list: after a successful creation the
  /// remaining pages are paged forward so the new comment is visible, then it
  /// is appended when the server-side ordering has not caught up yet.
  /// Concurrent submissions are serialized (see [_submitTail]). Throws
  /// [PlatformApiException] (`forbidden` on 403) or
  /// [PlatformAuthRequiredException] on failure.
  Future<void> submit(String body) {
    final run = _submitTail.then((_) => _submitNow(body));
    _submitTail = run.catchError((_) {});
    return run;
  }

  Future<void> _submitNow(String body) async {
    final session = await ref.read(platformSessionProvider.future);
    final created = await session.createComment(postId: postId, body: body);
    final current = state.value ?? const PlatformCommentState(comments: [], nextCursor: null);
    var comments = current.comments;
    var cursor = current.nextCursor;
    while (cursor != null) {
      final page = await session.listComments(postId, cursor: cursor);
      comments = [...comments, ...page.comments];
      cursor = page.nextCursor;
    }
    if (!comments.any((comment) => comment.commentId == created.commentId)) {
      comments = [...comments, created];
    }
    _generation++;
    state = AsyncData(PlatformCommentState(comments: comments, nextCursor: null));
    // Refresh the post record so the displayed comment count picks up the
    // new comment.
    ref.invalidate(platformPostProvider(postId));
  }
}
