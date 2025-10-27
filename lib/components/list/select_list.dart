import "package:flutter/material.dart";
import "package:flutter_breadcrumb/flutter_breadcrumb.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

// Generic, reusable nested select list with breadcrumb support.

/// A function that, given a root key and a WidgetRef, returns the list of its child roots.
typedef ChildrenFetcher<R> = List<R> Function(R root, WidgetRef ref);

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

  /// Fetch children for a given node. Must return synchronously.
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

  // Current (synchronously loaded) children for _currentRoot.
  List<R> _children = [];

  // Store last load error (if any).
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _currentRoot = widget.root;
    _loadChildrenForCurrentRoot();
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
      _loadChildrenForCurrentRoot();
    }
  }

  void _pushRoot(R newRoot) {
    setState(() {
      _history.add(_currentRoot);
      _currentRoot = newRoot;
    });
    _loadChildrenForCurrentRoot();
  }

  List<R> _loadChildrenForRoot(R root) {
    try {
      final result = widget.fetchChildren(root, ref);
      final filtered = (widget.validator == null)
          ? result
          : result.where(widget.validator!).toList();
      _loadError = null;
      return filtered;
    } catch (e) {
      _loadError = e;
      return <R>[];
    }
  }

  void _loadChildrenForCurrentRoot() {
    final children = _loadChildrenForRoot(_currentRoot);
    setState(() {
      _children = children;
    });
  }

  void _clearHistory() {
    setState(() {
      _history.clear();
      _currentRoot = widget.root;
    });
    _loadChildrenForCurrentRoot();
  }

  void _popToRoot(int index) {
    setState(() {
      _history.removeRange(index + 1, _history.length);
      if (_history.isNotEmpty) {
        _currentRoot = _history.removeLast();
      }
    });
    _loadChildrenForCurrentRoot();
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
        child: _loadError != null
            ? Center(child: Text("Error: \\${_loadError}"))
            : ListView.builder(
                itemCount: _children.length,
                itemBuilder: (ctx, i) {
                  final node = _children[i];
                  return widget.itemBuilder(node, () {
                    final shallSelect = widget.shallSelect?.call(node) ?? false;
                    if (shallSelect) {
                      widget.onSelect?.call(node);
                      return;
                    }
                    _pushRoot(node);
                  });
                },
              ),
      ),
    ],
  );
}
