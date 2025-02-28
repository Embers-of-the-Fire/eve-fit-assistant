import 'package:eve_fit_assistant/native/port/api/proxy.dart';
import 'package:eve_fit_assistant/storage/fit/fit.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/widgets/attribute.dart';
import 'package:eve_fit_assistant/widgets/description.dart';
import 'package:eve_fit_assistant/widgets/dynamic_attribute.dart';
import 'package:eve_fit_assistant/widgets/skill_tree.dart';
import 'package:flutter/material.dart';

part 'description.dart';
part 'skill.dart';
part 'traits.dart';

Future<void> showItemInfoPage(
  BuildContext context, {
  required int typeID,
  required ItemProxy item,
  required String fitID,
  DynamicItem? dynamicItem,
  void Function(int, double)? onDynamicAttributeChanged,
  void Function()? onDynamicAttributeReset,
  void Function()? onDynamicAttributeRandom,
}) async {
  await Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => ItemInfoPage(
            typeID: typeID,
            item: item,
            fitID: fitID,
            dynamicItem: dynamicItem,
          )));
}

Future<void> showTypeInfoPage(
  BuildContext context, {
  required int typeID,
}) async {
  await Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => ItemInfoPage(
            typeID: typeID,
            fitID: null,
            item: null,
            dynamicItem: null,
          )));
}

class ItemInfoPage extends StatefulWidget {
  final int typeID;
  final DynamicItem? dynamicItem;
  final String? fitID;

  final ItemProxy? item;

  const ItemInfoPage({
    super.key,
    required this.typeID,
    required this.fitID,
    required this.item,
    required this.dynamicItem,
  });

  @override
  State<ItemInfoPage> createState() => _ItemInfoPageState();
}

class _ItemInfoPageState extends State<ItemInfoPage> with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    final int pageCount = (widget.item?.charge == null ? 3 : 5) +
        (GlobalStorage().static.types[widget.typeID]?.traits != null ? 1 : 0) +
        (widget.item?.isDynamic ?? false ? 1 : 0);
    _controller = TabController(length: pageCount, vsync: this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> tabLabels = [];
    final List<Widget> tabs = [];

    if (GlobalStorage().static.types[widget.typeID]?.traits != null) {
      tabLabels.add('特性');
      tabs.add(TraitsTab(typeID: widget.typeID));
    }
    if (widget.item?.isDynamic ?? false) {
      tabLabels.add('动态属性');
      tabs.add(DynamicAttributeTab(
        fitID: widget.fitID!,
        typeID: widget.dynamicItem!.baseType,
        mutaplasmidID: widget.dynamicItem!.mutaplasmidID,
        itemID: widget.item!.itemId,
        attributes: widget.dynamicItem!.dynamicAttributes,
      ));
    }
    tabLabels.addAll(['描述', '属性', '技能']);
    tabs.addAll([
      DescriptionTab(typeID: widget.typeID),
      AttributeTab(typeID: widget.typeID, attr: widget.item?.attributes),
      SkillTree(rootID: widget.typeID),
    ]);
    if (widget.item?.charge != null) {
      tabLabels.addAll(['弹药属性', '弹药技能']);
      tabs.add(
          AttributeTab(typeID: widget.item!.charge!.itemId, attr: widget.item!.charge!.attributes));
      tabs.add(SkillTree(rootID: widget.item!.charge!.itemId));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('物品信息'),
        bottom: TabBar(
          isScrollable: true,
          controller: _controller,
          tabAlignment: TabAlignment.center,
          tabs: tabLabels.map((label) => Tab(text: label)).toList(),
        ),
      ),
      body: TabBarView(controller: _controller, children: tabs),
    );
  }
}
