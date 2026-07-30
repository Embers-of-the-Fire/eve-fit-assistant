import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/features/manual/manual.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

const Duration _debounceDelay = Duration(milliseconds: 250);

/// Open the vitepress-style manual search sheet.
Future<void> showManualSearchSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => const ManualSearchSheet(),
);

class ManualSearchSheet extends ConsumerStatefulWidget {
  const ManualSearchSheet({super.key});

  @override
  ConsumerState<ManualSearchSheet> createState() => _ManualSearchSheetState();
}

class _ManualSearchSheetState extends ConsumerState<ManualSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = "";
  Future<List<ManualSearchResult>>? _results;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      setState(() {
        _query = value;
        _results = _executeSearch(value);
      });
    });
  }

  Future<List<ManualSearchResult>>? _executeSearch(String value) {
    final service = ref.read(manualSearchServiceProvider).value;
    return service?.search(value, context.locale.toString());
  }

  @override
  Widget build(BuildContext context) {
    final serviceAsync = ref.watch(manualSearchServiceProvider);

    ref.listen(manualSearchServiceProvider, (prev, next) {
      if (next.hasValue && _query.isNotEmpty && _results == null) {
        setState(() {
          _results = _executeSearch(_query);
        });
      }
    });

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: context.mediaQuery.size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: context.l10n.manualSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: context.l10n.manualSearchClear,
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            _onQueryChanged("");
                          },
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: switch (serviceAsync) {
                AsyncError() => _SearchMessage(message: context.l10n.manualSearchUnavailable),
                AsyncLoading() => const Center(child: CircularProgressIndicator()),
                _ => _SearchResultList(query: _query, results: _results),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        message,
        style: context.theme.textTheme.titleMedium?.copyWith(
          color: context.theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _SearchResultList extends ConsumerWidget {
  const _SearchResultList({required this.query, required this.results});

  final String query;
  final Future<List<ManualSearchResult>>? results;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = results;
    if (future == null || normalizeSearchText(query).isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<ManualSearchResult>>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (data.isEmpty) {
          return _SearchMessage(message: context.l10n.manualSearchNoResults);
        }

        final tree = ref.watch(manualTreeProvider).value;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          itemCount: data.length,
          itemBuilder: (context, index) => _SearchResultTile(
            result: data[index],
            breadcrumb: tree == null ? null : _breadcrumbFor(tree, data[index].docId, context),
          ),
        );
      },
    );
  }

  String? _breadcrumbFor(ManualFolderEntry root, String docId, BuildContext context) {
    final localeCode = context.locale.toString();
    return switch (resolveManualPath(root, docId)) {
      ManualDocResolution(ancestors: final ancestors) when ancestors.isNotEmpty =>
        ancestors.map((folder) => folder.resolveName(localeCode) ?? folder.id).join(" / "),
      _ => null,
    };
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.result, required this.breadcrumb});

  final ManualSearchResult result;
  final String? breadcrumb;

  @override
  Widget build(BuildContext context) {
    final highlightStyle = context.theme.textTheme.titleMedium?.copyWith(
      color: context.theme.colorScheme.primary,
      fontWeight: FontWeight.bold,
    );
    final snippetHighlightStyle = context.theme.textTheme.bodyMedium?.copyWith(
      color: context.theme.colorScheme.primary,
      fontWeight: FontWeight.bold,
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: context.theme.colorScheme.surfaceContainer,
      child: InkWell(
        onTap: () {
          final router = context.router;
          Navigator.of(context).pop();
          unawaited(router.pushPath("/manual/${result.docId}"));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                _highlighted(result.title, result.titleRanges, highlightStyle),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.theme.textTheme.titleMedium,
              ),
              if (breadcrumb != null) ...[
                const SizedBox(height: 2),
                Text(
                  breadcrumb!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (result.snippet.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text.rich(
                  _highlighted(result.snippet.text, result.snippet.ranges, snippetHighlightStyle),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.bodyMedium?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
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

TextSpan _highlighted(String text, List<MatchRange> ranges, TextStyle? highlightStyle) {
  if (ranges.isEmpty) return TextSpan(text: text);
  final spans = <TextSpan>[];
  var cursor = 0;
  for (final range in ranges) {
    if (range.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, range.start)));
    }
    spans.add(TextSpan(text: text.substring(range.start, range.end), style: highlightStyle));
    cursor = range.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor)));
  }
  return TextSpan(children: spans);
}
