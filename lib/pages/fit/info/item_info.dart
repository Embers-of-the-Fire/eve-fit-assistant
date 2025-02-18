import 'package:eve_fit_assistant/native/port/api/proxy.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/widgets/attribute.dart';
import 'package:eve_fit_assistant/widgets/skill_tree.dart';
import 'package:flutter/material.dart';

part 'description.dart';
part 'skill.dart';

Future<void> showItemInfoPage(
  BuildContext context, {
  required int typeID,
  required ItemProxy item,
}) async {
  await Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => ItemInfoPage(
            typeID: typeID,
            item: item,
          )));
}

class ItemInfoPage extends StatefulWidget {
  final int typeID;
  final ItemProxy item;

  const ItemInfoPage({super.key, required this.typeID, required this.item});

  @override
  State<ItemInfoPage> createState() => _ItemInfoPageState();
}

class _ItemInfoPageState extends State<ItemInfoPage> with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    _controller = TabController(length: widget.item.charge == null ? 3 : 5, vsync: this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) =>
      widget.item.charge == null ? renderNoCharge(context) : renderWithCharge(context);

  Widget renderNoCharge(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('物品信息'),
          bottom: TabBar(
            controller: _controller,
            tabs: const [
              Tab(text: '描述'),
              Tab(text: '属性'),
              Tab(text: '技能'),
              // future feature:
              // Tab(text: '制造'),
              // Tab(text: '市场')
            ],
          ),
        ),
        body: TabBarView(controller: _controller, children: [
          DescriptionTab(typeID: widget.typeID),
          AttributeTab(typeID: widget.typeID, attr: widget.item.attributes),
          // const Center(child: Text('Work in Progress...', style: TextStyle(fontSize: 32))),
          SkillTree(rootID: widget.typeID),
        ]),
      );

  Widget renderWithCharge(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('物品信息'),
          bottom: TabBar(
            labelPadding: EdgeInsets.zero,
            controller: _controller,
            tabs: const [
              Tab(text: '描述'),
              Tab(text: '属性'),
              Tab(text: '弹药属性'),
              Tab(text: '技能'),
              Tab(text: '弹药技能'),
              // future feature:
              // Tab(text: '制造'),
              // Tab(text: '市场')
            ],
          ),
        ),
        body: TabBarView(controller: _controller, children: [
          DescriptionTab(typeID: widget.typeID),
          AttributeTab(typeID: widget.typeID, attr: widget.item.attributes),
          AttributeTab(typeID: widget.item.charge!.itemId, attr: widget.item.charge!.attributes),
          // const Center(child: Text('Work in Progress...', style: TextStyle(fontSize: 32))),
          SkillTree(rootID: widget.typeID),
          SkillTree(rootID: widget.item.charge!.itemId),
        ]),
      );
}
