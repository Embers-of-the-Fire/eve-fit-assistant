import 'dart:async';

import 'package:eve_fit_assistant/pages/fit/info/item_info.dart';
import 'package:eve_fit_assistant/pages/market/market_list.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:eve_fit_assistant/web/market/market.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MarketOrderPage extends ConsumerStatefulWidget {
  final int typeID;
  final int timestamp;

  const MarketOrderPage({super.key, required this.typeID, required this.timestamp});

  @override
  ConsumerState createState() => _MarketOrderPageState();
}

class _MarketOrderPageState extends ConsumerState<MarketOrderPage> {
  int timestamp = 0;

  @override
  void initState() {
    super.initState();
    timestamp = widget.timestamp;
  }

  void _refresh() {
    setState(() {
      GlobalStorage().market.clearCache(widget.typeID);
      timestamp = DateTime.now().millisecondsSinceEpoch;
    });
  }

  @override
  Widget build(BuildContext context) {
    final price = ref.watch(getMarketPriceProvider(widget.typeID, timestamp));

    final content = switch (price) {
      AsyncData(:final value) => RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight,
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading:
                          GlobalStorage().static.icons.getTypeIconSync(widget.typeID, scale: 1),
                      title: Text(GlobalStorage().static.types[widget.typeID]?.nameZH ??
                          '未知物品 ${widget.typeID}'),
                      onLongPress: () => showTypeInfoPage(context, typeID: widget.typeID),
                    ),
                    const Divider(height: 0),
                    Expanded(
                        child: DefaultTabController(
                      length: 2, // 标签数量
                      child: Column(children: [
                        const TabBar(tabs: [Tab(text: '欧服'), Tab(text: '国服')]),
                        Expanded(
                            child: TabBarView(children: [
                          _ServerOrderList(
                              onRefresh: () async => _refresh(), price: value.tranquility),
                          _ServerOrderList(
                              onRefresh: () async => _refresh(), price: value.serenity),
                        ]))
                      ]),
                    ))
                  ],
                ),
              ),
            ),
          ),
        ),
      AsyncError(:final error) => Center(
          child: Padding(
              padding: const EdgeInsets.all(50),
              child: Text(
                '出错了！：\n$error',
                softWrap: true,
              ))),
      AsyncLoading() || _ => const Center(child: CircularProgressIndicator())
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('市场 - ${GlobalStorage().static.types[widget.typeID]?.nameZH ?? '未知物品'}'),
        centerTitle: true,
      ),
      body: SafeArea(bottom: true, child: content),
    );
  }
}

class _ServerOrderList extends StatelessWidget {
  final FutureOr<void> Function() onRefresh;
  final MarketPrice price;

  const _ServerOrderList({required this.onRefresh, required this.price});

  @override
  Widget build(BuildContext context) => Column(children: [
        Flexible(
            child: Column(children: [
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '卖单',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              )),
          Expanded(
              child: DecoratedBox(
                  decoration: const BoxDecoration(
                      border: Border.symmetric(horizontal: BorderSide(color: Colors.grey))),
                  child: _OrderList(onRefresh: onRefresh, orders: price.orders.sell)))
        ])),
        Flexible(
            child: Column(children: [
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '买单',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              )),
          Expanded(
              child: DecoratedBox(
                  decoration:
                      const BoxDecoration(border: Border(top: BorderSide(color: Colors.grey))),
                  child: _OrderList(onRefresh: onRefresh, orders: price.orders.buy)))
        ])),
      ]);
}

class _OrderList extends StatelessWidget {
  final FutureOr<void> Function() onRefresh;
  final List<Order> orders;

  const _OrderList({required this.onRefresh, required this.orders});

  @override
  Widget build(BuildContext context) => RefreshIndicator(
      onRefresh: () async => await onRefresh(),
      child: ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) => ListTile(
                title: Text('ISK ${orders[index].price.moneyFormat}'),
                trailing: Text(
                  '${orders[index].volumeRemain.separate}/${orders[index].volumeTotal.separate}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                ),
              )));
}
