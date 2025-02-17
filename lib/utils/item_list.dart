part of 'utils.dart';

class ItemList extends StatefulWidget {
  final EdgeInsets? breadcrumbPadding;
  final Decoration? breadcrumbDecoration;
  final EdgeInsets? breadcrumbItemPadding;
  final String? baseGroup;

  final int? fallbackGroupID;

  final bool Function(int id)? filter;
  final void Function(int id)? onSelect;

  const ItemList({
    super.key,
    this.breadcrumbPadding,
    this.breadcrumbDecoration,
    this.breadcrumbItemPadding,
    this.baseGroup,
    this.fallbackGroupID,
    this.filter,
    this.onSelect,
  });

  @override
  State<ItemList> createState() => _ItemListState();
}

class _ItemListState extends State<ItemList> {
  final ScrollController _breadcrumbController = ScrollController();
  final ScrollController _shipListController = ScrollController();

  List<int> _breadcrumbs = [];
  List<String> _breadcrumbNames = [];
  final Set<int> _cachedValidTypes = {};
  final Set<int> _cachedValidGroups = {};

  @override
  void initState() {
    super.initState();
    _resetBreadcrumbs();
  }

  void _resetBreadcrumbs() {
    setState(() {
      _breadcrumbs = [];
      _breadcrumbNames = [];
    });
  }

  bool _isTypeValid(int id) {
    if (_cachedValidTypes.contains(id)) {
      return true;
    }
    final type = GlobalStorage().static.types[id];
    if (type == null) {
      return false;
    }
    if (widget.filter?.call(id) ?? true) {
      _cachedValidTypes.add(id);
      return true;
    }
    return false;
  }

  bool _isGroupValid(int id) {
    if (_cachedValidGroups.contains(id)) {
      return true;
    }
    final group = GlobalStorage().static.marketGroups[id];
    if (group == null) {
      return false;
    }
    final subGroup = group.childGroups;
    if (subGroup.any((id) => _isGroupValid(id)) || group.types.any((id) => _isTypeValid(id))) {
      _cachedValidGroups.add(id);
      return true;
    }
    return false;
  }

  void _expandGroup(int id) {
    final group = GlobalStorage().static.marketGroups[id];

    if (group == null) return;

    setState(() {
      _breadcrumbs.add(id);
      _breadcrumbNames.add(group.nameZH);
    });
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: double.infinity,
            padding: widget.breadcrumbPadding,
            decoration: widget.breadcrumbDecoration,
            child: BreadCrumb(
              items: [
                BreadCrumbItem(
                  content: Container(
                    padding: widget.breadcrumbItemPadding,
                    child: Text(widget.baseGroup ?? '总览', style: const TextStyle(fontSize: 16)),
                  ),
                  onTap: () => _resetBreadcrumbs(),
                ),
                ..._breadcrumbNames.enumerate().map((el) => BreadCrumbItem(
                      content: Container(
                        padding: widget.breadcrumbItemPadding,
                        child: Text(el.$2, style: const TextStyle(fontSize: 16)),
                      ),
                      onTap: () => setState(() {
                        _breadcrumbs.removeRange(el.$1 + 1, _breadcrumbs.length);
                        _breadcrumbNames.removeRange(el.$1 + 1, _breadcrumbNames.length);
                      }),
                    ))
              ],
              divider: const Icon(Icons.chevron_right),
              overflow: ScrollableOverflow(
                direction: Axis.horizontal,
                keepLastDivider: true,
                controller: _breadcrumbController,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              controller: _shipListController,
              child: Column(
                children: [
                  ..._filterMarketGroups(_breadcrumbs.lastOrNull ?? widget.fallbackGroupID)
                      .filterMap(
                          (id) => GlobalStorage().static.marketGroups[id].map((v) => (id, v)))
                      .filter((it) => _isGroupValid(it.$1))
                      .map((it) => _groupListTile(it.$2, onTap: () => _expandGroup(it.$1))),
                  ...(_breadcrumbs.lastOrNull ?? widget.fallbackGroupID)
                      .andThen((id) => GlobalStorage().static.marketGroups[id])
                      .map((group) => _itemListTile(
                            group,
                            onTap: widget.onSelect,
                            filter: widget.filter,
                          ))
                      .unwrapOr([])
                ],
              ),
            ),
          )
        ],
      );
}

ListTile _groupListTile(MarketGroup group, {void Function()? onTap}) {
  final image =
      group.iconID.andThen((id) => GlobalStorage().static.icons.getIconSync(id, height: 32));
  final Widget leading;
  if (image != null) {
    leading = image;
  } else {
    leading = Icon(group.hasTypes ? Icons.list_sharp : Icons.folder_copy_sharp);
  }

  return ListTile(
    leading: leading,
    title: Text(group.nameZH),
    onTap: onTap,
  );
}

Iterable<ListTile> _itemListTile(MarketGroup group,
    {void Function(int id)? onTap, bool Function(int id)? filter}) {
  late Iterable<int> types;
  if (filter == null) {
    types = group.types;
  } else {
    types = group.types.filter(filter);
  }
  return types
      .filterMap((id) => GlobalStorage().static.types[id].map((u) => (id, u)))
      .map((val) => ListTile(
            // leading: Icon(Icons.article_sharp),
            leading: GlobalStorage().static.icons.getTypeIconSync(val.$1),
            title: Text(
              val.$2.nameZH,
              softWrap: true,
            ),
            onTap: () => onTap?.call(val.$1),
          ));
}

Iterable<int> _filterMarketGroups(
  int? parentID,
) {
  if (parentID == null) {
    return GlobalStorage()
        .static
        .marketGroups
        .entries
        .filter((t) => !t.value.hasParent)
        .map((t) => t.key);
  }

  final map = GlobalStorage().static.marketGroups[parentID];
  if (map == null) {
    return const [];
  } else {
    return map.childGroups;
  }
}
