import 'package:eve_fit_assistant/pages/fit/info/item_info.dart';
import 'package:eve_fit_assistant/pages/market/market_order.dart';
import 'package:eve_fit_assistant/storage/preference/preference.dart';
import 'package:eve_fit_assistant/storage/static/market.dart';
import 'package:eve_fit_assistant/storage/static/types.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:eve_fit_assistant/web/market/market.dart';
import 'package:flutter/material.dart';
import 'package:flutter_breadcrumb/flutter_breadcrumb.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'market_list.g.dart';
part 'market_tile.dart';

class MarketList extends StatefulWidget {
  const MarketList({super.key});

  @override
  State<MarketList> createState() => _MarketListState();
}

class _MarketListState extends State<MarketList> {
  final ScrollController _breadcrumbController = ScrollController();
  final ScrollController _shipListController = ScrollController();
  final FToast fToast = FToast();

  List<int> _breadcrumbs = [];
  List<String> _breadcrumbNames = [];
  final Set<int> _cachedValidTypes = {};
  final Set<int> _cachedValidGroups = {};

  int timestamp = 0;

  @override
  void initState() {
    super.initState();
    _resetBreadcrumbs();
    fToast.init(context);
    timestamp = DateTime.now().millisecondsSinceEpoch;
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
    if (GlobalStorage().static.types[id]?.published == true) {
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

  void _onTapItem(int id) {
    if (GlobalPreference.marketApi == MarketApi.cEveMarket) {
      fToast.showToast(
          gravity: ToastGravity.CENTER,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25.0),
              color: Colors.red,
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline),
              SizedBox(width: 12.0),
              Text('CEVE 接口不支持查看订单详情'),
            ]),
          ));
    } else {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => MarketOrderPage(
                typeID: id,
                timestamp: timestamp,
              )));
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: GlobalPreference.itemListPopBehavior != ItemListPopBehavior.prevPage,
      onPopInvokedWithResult: (GlobalPreference.itemListPopBehavior == ItemListPopBehavior.prevPage)
          .thenSome((pop, _) async {
        if (pop) return;
        if (_breadcrumbs.isEmpty) {
          Navigator.of(context).pop();
        } else {
          setState(() {
            _breadcrumbs.removeLast();
            _breadcrumbNames.removeLast();
          });
        }
      }),
      child: Column(
        children: [
          TypeAheadField<(int, TypeItem)>(
            onSelected: (data) => _onTapItem(data.$1),
            builder: (context, controller, focusNode) => Padding(
                padding: const EdgeInsets.only(top: 10, left: 5, right: 5),
                child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: false,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: '物品',
                    ))),
            itemBuilder: (context, data) {
              final id = data.$1;
              final ship = data.$2;
              return ListTile(
                leading: GlobalStorage().static.icons.getTypeIconSync(id),
                title: Text(ship.nameZH),
                subtitle: GlobalStorage().static.groups[ship.groupID]?.nameZH.text(),
                onTap: () => _onTapItem(id),
                onLongPress: () => showTypeInfoPage(context, typeID: id),
              );
            },
            suggestionsCallback: (search) => search.isNotEmpty.then(() => GlobalStorage()
                .static
                .types
                .tupleEntries
                .filter((data) => data.$2.published && data.$2.nameZH.contains(search))
                .toList()),
            emptyBuilder: (context) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '未找到相关物品',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey)),
            ),
            child: BreadCrumb(
              items: [
                BreadCrumbItem(
                  content: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: const Text('总览', style: TextStyle(fontSize: 16)),
                  ),
                  onTap: () => _resetBreadcrumbs(),
                ),
                ..._breadcrumbNames.enumerate().map((el) => BreadCrumbItem(
                      content: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
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
              child: RefreshIndicator(
            onRefresh: () async => setState(() {
              GlobalStorage().market.clearCache();
              timestamp = DateTime.now().millisecondsSinceEpoch;
            }),
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _shipListController,
                children: [
                  ..._filterMarketGroups(_breadcrumbs.lastOrNull)
                      .filterMap(
                          (id) => GlobalStorage().static.marketGroups[id].map((v) => (id, v)))
                      .filter((it) => _isGroupValid(it.$1))
                      .map((it) => _groupListTile(it.$2, onTap: () => _expandGroup(it.$1))),
                  ..._breadcrumbs.lastOrNull
                      .andThen((id) => GlobalStorage().static.marketGroups[id])
                      .map((group) =>
                          _itemListTile(context, group, timestamp: timestamp, onTap: _onTapItem))
                      .unwrapOr([])
                ]),
          ))
        ],
      ));
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

Iterable<Widget> _itemListTile(
  BuildContext context,
  MarketGroup group, {
  required void Function(int id) onTap,
  required int timestamp,
}) {
  late Iterable<int> types;
  types = group.types.filter((id) => GlobalStorage().static.types[id]?.published == true);
  return types.filterMap((id) => GlobalStorage().static.types[id].map((u) => (id, u))).map((val) =>
      MarketListTile(
          name: val.$2.nameZH,
          typeID: val.$1,
          timestamp: timestamp,
          onLongPress: () => showTypeInfoPage(context, typeID: val.$1),
          onTap: () => onTap(val.$1)));
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
