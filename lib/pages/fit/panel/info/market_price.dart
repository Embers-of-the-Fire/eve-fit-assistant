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
      AsyncData(:final value) => Column(children: [
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
        ]),
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
      builder: (context) => Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: AlertDialog(
              title: const Text('无市场价格的装备'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
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
            ),
          ));
}
