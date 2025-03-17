import 'package:eve_fit_assistant/storage/preference/preference.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_breadcrumb/flutter_breadcrumb.dart';

class ItemGroupList extends StatefulWidget {
  final EdgeInsets? breadcrumbPadding;
  final EdgeInsets? breadcrumbItemPadding;
  final String? baseGroup;

  final int categoryID;

  final void Function(int id)? onSelect;
  final void Function(int id)? onLongPress;

  const ItemGroupList(
      {super.key,
      this.breadcrumbPadding,
      this.breadcrumbItemPadding,
      this.baseGroup,
      required this.categoryID,
      this.onSelect,
      this.onLongPress});

  @override
  State<ItemGroupList> createState() => _ItemGroupListState();
}

class _ItemGroupListState extends State<ItemGroupList> {
  final ScrollController _breadcrumbController = ScrollController();
  final ScrollController _shipListController = ScrollController();

  int? groupID;
  String? groupName;

  @override
  void initState() {
    super.initState();
    _resetBreadcrumbs();
  }

  void _resetBreadcrumbs() {
    setState(() {
      groupID = null;
      groupName = null;
    });
  }

  void _expandGroup(int id) {
    final group = GlobalStorage().static.groups[id];
    if (group == null) return;
    setState(() {
      groupID = id;
      groupName = group.nameZH;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: Preference().itemListPopBehavior != ItemListPopBehavior.prevPage,
        onPopInvokedWithResult: (Preference().itemListPopBehavior == ItemListPopBehavior.prevPage)
            .thenSome((pop, _) async {
          if (pop) return;
          if (groupID == null) {
            Navigator.of(context).pop();
          } else {
            _resetBreadcrumbs();
          }
        }),
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: widget.breadcrumbPadding,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: BreadCrumb(
              items: [
                BreadCrumbItem(
                  content: Container(
                    padding: widget.breadcrumbItemPadding,
                    child: Text(widget.baseGroup ?? '总览', style: const TextStyle(fontSize: 16)),
                  ),
                  onTap: () => _resetBreadcrumbs(),
                ),
                if (groupID != null && groupName != null)
                  BreadCrumbItem(
                      content: Container(
                        padding: widget.breadcrumbItemPadding,
                        child: Text(groupName!, style: const TextStyle(fontSize: 16)),
                      ),
                      onTap: () => setState(() {})),
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
              child: Scrollbar(
                  child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      controller: _shipListController,
                      child: Column(children: [
                        if (groupID == null)
                          for (final entry in GlobalStorage().static.groups.entries)
                            if (entry.value.categoryID == widget.categoryID)
                              ListTile(
                                title: Text(entry.value.nameZH),
                                onTap: () => _expandGroup(entry.key),
                              ),
                        if (groupID != null)
                          for (final entry in GlobalStorage().static.types.entries)
                            if (entry.value.groupID == groupID && entry.value.published)
                              ListTile(
                                leading: GlobalStorage().static.icons.getTypeIconSync(entry.key),
                                title: Text(entry.value.nameZH),
                                onTap: () => widget.onSelect?.call(entry.key),
                                onLongPress: () => widget.onLongPress?.call(entry.key),
                              )
                      ]))))
        ]),
      );
}
