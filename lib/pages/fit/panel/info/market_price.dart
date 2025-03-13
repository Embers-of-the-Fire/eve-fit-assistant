part of 'info_component.dart';

@riverpod
Future<(double, Iterable<int>, double, Iterable<int>)> getMarketPrices(
    Ref ref, MapEqual<int, int> types) async {
  final tqPrices = await Future.wait(types.map.entries.map((entry) async {
    final price = await GlobalStorage().market.getPrice(entry.key, Server.tranquility);
    return (price.summary.sell.min * entry.value, entry.key);
  }));
  final sePrices = await Future.wait(types.map.entries.map((entry) async {
    final price = await GlobalStorage().market.getPrice(entry.key, Server.serenity);
    return (price.summary.sell.min * entry.value, entry.key);
  }));
  return (
    tqPrices.map((u) => u.$1).sum(),
    tqPrices.filter((u) => u.$1 == 0).map((u) => u.$2),
    sePrices.map((u) => u.$1).sum(),
    sePrices.filter((u) => u.$1 == 0).map((u) => u.$2),
  );
}

const _defaultTextStyle = TextStyle(
  color: Colors.white,
  fontSize: 16,
  fontWeight: FontWeight.normal,
);

class MarketPriceInfo extends ConsumerWidget {
  final String fitID;

  const MarketPriceInfo({super.key, required this.fitID});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = ref.watch(fitRecordNotifierProvider(fitID));

    final Map<int, int> itemCount = {};
    itemCount[fit.fit.body.shipID] = 1;
    for (final item in [
      fit.fit.body.high,
      fit.fit.body.med,
      fit.fit.body.low,
      fit.fit.body.rig,
      fit.fit.body.subsystem,
      fit.fit.body.implant,
    ].flatten().filterNotNull()) {
      final itemID = item.isDynamic ? fit.fit.body.dynamicItems[item.itemID]!.outType : item.itemID;
      itemCount[itemID] = (itemCount[itemID] ?? 0) + 1;
    }
    for (final item in fit.fit.body.drone) {
      itemCount[item.itemID] = (itemCount[item.itemID] ?? 0) + item.amount;
    }
    for (final item in fit.fit.body.fighter) {
      itemCount[item.itemID] = (itemCount[item.itemID] ?? 0) + item.amount;
    }
    final sumPrice = ref.watch(getMarketPricesProvider(MapEqual(itemCount)));

    return switch (sumPrice) {
      AsyncError(:final error) => ListTile(
          leading: const SizedBox(width: 32),
          subtitle: Text('网络连接出错：$error', softWrap: true),
        ),
      AsyncData(:final value) => InkWell(
          onLongPress: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (context) => _MarketPriceDetail(fitID: fitID))),
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.only(left: 18, right: 22, top: 6),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('欧服', style: _defaultTextStyle),
                      if (value.$2.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 1, left: 10),
                            child: Ink(
                                decoration: const BoxDecoration(
                                    borderRadius: BorderRadius.all(Radius.circular(50))),
                                child: InkWell(
                                  borderRadius: const BorderRadius.all(Radius.circular(50)),
                                  onTap: () => _showMarketPriceErrorInfo(context, value.$2),
                                  child: const Icon(Icons.info_outline, color: Colors.red),
                                )))
                    ],
                  ),
                  Text('${value.$1.moneyFormat} ISK', style: _defaultTextStyle)
                ])),
            Padding(
                padding: const EdgeInsets.only(left: 18, right: 22, top: 6, bottom: 10),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('国服', style: _defaultTextStyle),
                      if (value.$4.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 1, left: 10),
                            child: Ink(
                                decoration: const BoxDecoration(
                                    borderRadius: BorderRadius.all(Radius.circular(50))),
                                child: InkWell(
                                  borderRadius: const BorderRadius.all(Radius.circular(50)),
                                  onTap: () => _showMarketPriceErrorInfo(context, value.$4),
                                  child: const Icon(Icons.info_outline, color: Colors.red),
                                )))
                    ],
                  ),
                  Text('${value.$3.moneyFormat} ISK', style: _defaultTextStyle)
                ])),
          ])),
      AsyncLoading() || _ => const ListTile(
            title: Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 10, children: [
          SizedBox(
              width: 24,
              height: 24,
              child: LoadingIndicator(indicatorType: Indicator.lineScale, colors: [Colors.white])),
          Text('加载中...')
        ]))
    };
  }
}

Future<void> _showMarketPriceErrorInfo(BuildContext context, Iterable<int> items) async {
  await showDialog(
    context: context,
    builder: (context) => _MarketPriceNotFoundDialog(items: items),
  );
}

class _MarketPriceNotFoundDialog extends StatelessWidget {
  final Iterable<int> items;

  const _MarketPriceNotFoundDialog({required this.items});

  @override
  Widget build(BuildContext context) => AppDialog(
        title: '无市场价格的装备',
        contentTextStyle: const TextStyle(fontSize: 18),
        content: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 300),
            child: SingleChildScrollView(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items
                  .map((id) => ListTile(
                        leading: GlobalStorage().static.icons.getTypeIconSync(id),
                        title: Text(GlobalStorage().static.types[id]!.nameZH),
                        onLongPress: () => showTypeInfoPage(context, typeID: id),
                      ))
                  .toList(),
            ))),
      );
}

@riverpod
Future<MarketPriceGroup> getMarketPrice(Ref ref, int typeID) async => MarketPriceGroup(
    typeID: typeID,
    tranquility: await GlobalStorage().market.getPrice(typeID, Server.tranquility),
    serenity: await GlobalStorage().market.getPrice(typeID, Server.serenity));

class _MarketPriceDetail extends StatelessWidget {
  final String fitID;

  const _MarketPriceDetail({required this.fitID});

  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('市场价格详情'),
          bottom: const TabBar(
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [Tab(text: '欧服'), Tab(text: '国服')],
          ),
        ),
        body: TabBarView(children: [
          _MarketPriceDetailList(fitID: fitID, server: Server.tranquility),
          _MarketPriceDetailList(fitID: fitID, server: Server.serenity)
        ]),
      ));
}

class _MarketPriceDetailList extends ConsumerWidget {
  final String fitID;
  final Server server;

  const _MarketPriceDetailList({required this.fitID, required this.server});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = ref.watch(fitRecordNotifierProvider(fitID));

    final List<Widget> children = [];
    double allPrice = 0;
    bool allPriceLoaded = true;

    {
      // ship
      final (trailing, gotPrice) = _getItemPriceTrailing(ref, server, fit.fit.body.shipID, 1);
      children.addAll([
        ListTile(
            title: const Text('舰船总价'),
            trailing: gotPrice == null
                ? _loadingIndicator
                : Text(
                    '${gotPrice.moneyFormat} ISK',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                  )),
        const Divider(height: 4),
        ListTile(
          leading: GlobalStorage().static.icons.getTypeIconSync(fit.fit.body.shipID),
          title: Text(GlobalStorage().static.types[fit.fit.body.shipID]?.nameZH ??
              '未知 ${fit.fit.body.shipID}'),
          trailing: trailing,
        ),
        const Divider(height: 4, color: Colors.white),
      ]);
      allPriceLoaded = allPriceLoaded && gotPrice != null;
      allPrice += gotPrice ?? 0.0;
    }

    {
      // equipment
      bool equipmentPriceLoaded = true;
      double equipmentPrice = 0;
      final List<ListTile> equipment = [];
      final Map<int, int> itemCount = {};
      for (final item in [
        fit.fit.body.high,
        fit.fit.body.med,
        fit.fit.body.low,
        fit.fit.body.rig,
        fit.fit.body.subsystem,
      ].flatten().filterNotNull()) {
        final itemID =
            item.isDynamic ? fit.fit.body.dynamicItems[item.itemID]!.outType : item.itemID;
        itemCount[itemID] = (itemCount[itemID] ?? 0) + 1;
      }
      for (final entry in itemCount.entries) {
        final (trailing, gotPrice) = _getItemPriceTrailing(ref, server, entry.key, entry.value);
        equipment.add(ListTile(
          leading: GlobalStorage().static.icons.getTypeIconSync(entry.key),
          title: Text(GlobalStorage().static.types[entry.key]?.nameZH ?? '未知 ${entry.key}'),
          trailing: trailing,
        ));
        equipmentPriceLoaded = equipmentPriceLoaded && gotPrice != null;
        equipmentPrice += (gotPrice ?? 0.0) * entry.value;
      }
      children.addAll([
        ListTile(
            title: const Text('装备总价'),
            trailing: equipmentPriceLoaded
                ? Text(
                    '${equipmentPrice.moneyFormat} ISK',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                  )
                : _loadingIndicator),
        const Divider(height: 4)
      ]);
      children.addAll(equipment);
      children.add(const Divider(height: 4, color: Colors.white));
      allPriceLoaded = allPriceLoaded && equipmentPriceLoaded;
      allPrice += equipmentPrice;
    }

    {
      // drone & fighter
      bool dronePriceLoaded = true;
      double dronePrice = 0;
      final List<ListTile> drone = [];
      final Map<int, int> itemCount = {};
      for (final item in fit.fit.body.drone) {
        itemCount[item.itemID] = (itemCount[item.itemID] ?? 0) + item.amount;
      }
      for (final item in fit.fit.body.fighter) {
        itemCount[item.itemID] = (itemCount[item.itemID] ?? 0) + item.amount;
      }
      for (final entry in itemCount.entries) {
        final (trailing, gotPrice) = _getItemPriceTrailing(ref, server, entry.key, entry.value);
        drone.add(ListTile(
          leading: GlobalStorage().static.icons.getTypeIconSync(entry.key),
          title: Text(GlobalStorage().static.types[entry.key]?.nameZH ?? '未知 ${entry.key}'),
          trailing: trailing,
        ));
        dronePriceLoaded = dronePriceLoaded && gotPrice != null;
        dronePrice += (gotPrice ?? 0.0) * entry.value;
      }
      children.addAll([
        ListTile(
            title: const Text('无人机和舰载机总价'),
            trailing: dronePriceLoaded
                ? Text(
                    '${dronePrice.moneyFormat} ISK',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                  )
                : _loadingIndicator),
        const Divider(height: 4)
      ]);
      children.addAll(drone);
      children.add(const Divider(height: 4, color: Colors.white));
      allPriceLoaded = allPriceLoaded && dronePriceLoaded;
      allPrice += dronePrice;
    }

    {
      // implant
      bool implantPriceLoaded = true;
      double implantPrice = 0;
      final List<ListTile> implant = [];
      final Map<int, int> itemCount = {};
      for (final item in fit.fit.body.implant.filterNotNull()) {
        final itemID =
            item.isDynamic ? fit.fit.body.dynamicItems[item.itemID]!.outType : item.itemID;
        itemCount[itemID] = (itemCount[itemID] ?? 0) + 1;
      }
      for (final entry in itemCount.entries) {
        final (trailing, gotPrice) = _getItemPriceTrailing(ref, server, entry.key, entry.value);
        implant.add(ListTile(
          leading: GlobalStorage().static.icons.getTypeIconSync(entry.key),
          title: Text(GlobalStorage().static.types[entry.key]?.nameZH ?? '未知 ${entry.key}'),
          trailing: trailing,
        ));
        implantPriceLoaded = implantPriceLoaded && gotPrice != null;
        implantPrice += (gotPrice ?? 0.0) * entry.value;
      }
      children.addAll([
        ListTile(
            title: const Text('植入体总价'),
            trailing: implantPriceLoaded
                ? Text(
                    '${implantPrice.moneyFormat} ISK',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                  )
                : _loadingIndicator),
        const Divider(height: 4)
      ]);
      children.addAll(implant);
      children.add(const Divider(height: 4, color: Colors.white));
      allPriceLoaded = allPriceLoaded && implantPriceLoaded;
      allPrice += implantPrice;
    }

    children.insertAll(0, [
      ListTile(
          title: const Text('总价'),
          trailing: allPriceLoaded
              ? Text(
                  '${allPrice.moneyFormat} ISK',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                )
              : _loadingIndicator),
      const Divider(height: 4, color: Colors.white)
    ]);

    return Scrollbar(child: ListView(children: children));
  }
}

const _loadingIndicator = SizedBox(
  height: 20,
  child: LoadingIndicator(indicatorType: Indicator.lineScale, colors: [Colors.white]),
);

(Widget, double?) _getItemPriceTrailing(WidgetRef ref, Server server, int typeID, int amount) =>
    ref.watch(getMarketPriceProvider(typeID)).when<(Widget, double?)>(
        data: (data) => switch (server) {
              Server.tranquility => data.tranquility,
              Server.serenity => data.serenity
            }
                .summary
                .sell
                .min
                .let((u) => (
                      Text.rich(
                          TextSpan(children: [
                            TextSpan(text: '$amount× '),
                            TextSpan(
                                text: u.moneyFormat,
                                style:
                                    TextStyle(color: u > 0 ? Colors.grey.shade400 : Colors.orange)),
                            const TextSpan(text: ' ISK'),
                          ]),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal)),
                      u
                    )),
        error: (error, _) => (
              Text('错误：$error',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal)),
              null
            ),
        loading: () => (_loadingIndicator, null));
