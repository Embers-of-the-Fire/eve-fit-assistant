import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_breadcrumb/flutter_breadcrumb.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

// Generic, reusable nested select list with breadcrumb support.
// Inspired by eve_select_list.dart but abstracted for arbitrary root and item types.

/// A function that, given a root key and a WidgetRef, returns the list of its child roots.
typedef ChildrenFetcher<R> = FutureOr<List<R>> Function(R root, WidgetRef ref);

/// A predicate that validates whether a root should be visible/selectable.
typedef RootValidator<R> = bool Function(R root);

/// A function that maps a root to a user-visible widget used in the breadcrumb.
typedef BreadcrumbBuilder<R> = Widget Function(R root);

/// A function that maps a root to a list item widget displayed in the list.
/// onTap should be invoked when the item is selected.
typedef ItemBuilder<R> = Widget Function(R root, VoidCallback onTap);

/// A generic nested select list.
/// R - the type representing a node in the selection tree (e.g., int id or a model).
class SelectList<R> extends ConsumerStatefulWidget {
  const SelectList({
    required this.root,
    required this.fetchChildren,
    required this.breadcrumbBuilder,
    required this.itemBuilder,
    super.key,
    this.validator,
    this.shallSelect,
    this.onSelect,
  });

  /// The initial root node to display.
  final R root;

  /// Fetch children for a given node. May return synchronously or asynchronously.
  final ChildrenFetcher<R> fetchChildren;

  /// Build a breadcrumb widget for a node.
  final BreadcrumbBuilder<R> breadcrumbBuilder;

  /// Build a list item widget for a node. The provided onTap should be used to
  /// select or drill into the node.
  final ItemBuilder<R> itemBuilder;

  /// Optional validator to filter nodes. If null, all nodes are allowed.
  final RootValidator<R>? validator;

  /// Predicate that indicates whether selecting this node should cause the
  /// widget to treat it as a final selection (true) or drill into it (false).
  /// If null, defaults to false (drill until leaf).
  final RootValidator<R>? shallSelect;

  /// Callback when a node is selected (and not drilled into).
  final void Function(R node)? onSelect;

  @override
  ConsumerState<SelectList<R>> createState() => _SelectListState<R>();
}

class _SelectListState<R> extends ConsumerState<SelectList<R>> {
  final List<R> _history = [];
  late R _currentRoot;

  // Cached in-flight or completed children future for the current root.
  Future<List<R>>? _childrenFuture;

  // Loading indicator delay: only show spinner if loading exceeds this.
  final Duration _loadingDelay = const Duration(milliseconds: 150);
  Timer? _loadingTimer;
  bool _isLoading = false;
  bool _showLoading = false;

  @override
  void initState() {
    super.initState();
    _currentRoot = widget.root;
    _childrenFuture = _loadChildrenForRoot(_currentRoot);
  }

  @override
  void didUpdateWidget(covariant SelectList<R> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If parent changed the root, reset navigation state.
    if (oldWidget.root != widget.root) {
      setState(() {
        _history.clear();
        _currentRoot = widget.root;
      });
      _childrenFuture = _loadChildrenForRoot(_currentRoot);
    }
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  void _pushRoot(R newRoot) {
    setState(() {
      _history.add(_currentRoot);
      _currentRoot = newRoot;
    });
    _childrenFuture = _loadChildrenForRoot(newRoot);
  }

  // Load children and manage a short delay before showing a loading spinner.
  Future<List<R>> _loadChildrenForRoot(R root) {
    // Cancel any previous timer and mark loading state.
    _loadingTimer?.cancel();
    _isLoading = true;
    _showLoading = false;

    // Start a timer to show the spinner only if loading takes longer than [_loadingDelay].
    _loadingTimer = Timer(_loadingDelay, () {
      if (mounted && _isLoading) {
        setState(() {
          _showLoading = true;
        });
      }
    });

    final future = Future.value(widget.fetchChildren(root, ref))
        .then((result) {
          final filtered = (widget.validator == null)
              ? result
              : result.where(widget.validator!).toList();
          return filtered;
        })
        .whenComplete(() {
          _loadingTimer?.cancel();
          _isLoading = false;
          if (mounted) {
            setState(() {
              // hide spinner when finished; if the load was quick the spinner never showed.
              _showLoading = false;
            });
          }
        });

    return future;
  }

  void _clearHistory() {
    setState(() {
      _history.clear();
      _currentRoot = widget.root;
    });
    _childrenFuture = _loadChildrenForRoot(_currentRoot);
  }

  void _popToRoot(int index) {
    setState(() {
      _history.removeRange(index + 1, _history.length);
      if (_history.isNotEmpty) {
        _currentRoot = _history.removeLast();
      }
    });
    _childrenFuture = _loadChildrenForRoot(_currentRoot);
  }

  Widget _buildBreadcrumbItem(R node) => widget.breadcrumbBuilder(node);

  List<BreadCrumbItem> _buildBreadcrumbItems() {
    final items = <BreadCrumbItem>[];
    for (var i = 0; i < _history.length; i++) {
      final node = _history[i];
      items.add(BreadCrumbItem(content: _buildBreadcrumbItem(node), onTap: () => _popToRoot(i)));
    }
    // current root as last item; tapping it clears history (go to root)
    items.add(BreadCrumbItem(content: _buildBreadcrumbItem(_currentRoot), onTap: _clearHistory));
    return items;
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: BreadCrumb(
          items: _buildBreadcrumbItems(),
          divider: const Icon(Icons.chevron_right, size: 18),
          overflow: ScrollableOverflow(keepLastDivider: true),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<R>>(
          future: _childrenFuture ??= _loadChildrenForRoot(_currentRoot),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // Only show the progress indicator if the loading exceeded the short delay.
              if (_showLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              // Don't show the spinner for very short loads — avoid flicker.
              return const SizedBox.shrink();
            }
            if (snapshot.hasError) {
              return Center(child: Text("Error: \\${snapshot.error}"));
            }
            final children = snapshot.data ?? [];
            return ListView.builder(
              itemCount: children.length,
              itemBuilder: (ctx, i) {
                final node = children[i];
                return widget.itemBuilder(node, () {
                  final shallSelect = widget.shallSelect?.call(node) ?? false;
                  if (shallSelect) {
                    widget.onSelect?.call(node);
                    return;
                  }
                  _pushRoot(node);
                });
              },
            );
          },
        ),
      ),
    ],
  );
}
