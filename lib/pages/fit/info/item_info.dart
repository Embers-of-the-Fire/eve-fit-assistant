import 'package:eve_fit_assistant/native/port/api/proxy.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:flutter/material.dart';

part 'description.dart';

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
    _controller = TabController(length: 3, vsync: this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
          const Center(child: Text('Work in Progress...', style: TextStyle(fontSize: 32))),
          const Center(child: Text('Work in Progress...', style: TextStyle(fontSize: 32))),
        ]),
      );
}
