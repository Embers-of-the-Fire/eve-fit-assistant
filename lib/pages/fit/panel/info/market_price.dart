part of 'info_component.dart';

@riverpod
Future<(double, double)> getMarketPrices(Ref ref, MapEqual<int, int> types) async {
  final tqPrices = await Future.wait(types.map.entries.map((entry) async {
    final price = await GlobalStorage().market.getPrice(entry.key, Server.tranquility);
    return price.summary.sell.min * entry.value;
  }));
  final sePrices = await Future.wait(types.map.entries.map((entry) async {
    final price = await GlobalStorage().market.getPrice(entry.key, Server.serenity);
    return price.summary.sell.min * entry.value;
  }));
  return (tqPrices.sum(), sePrices.sum());
}

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
      itemCount[item.itemID] = (itemCount[item.itemID] ?? 0) + 1;
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
          ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            title: const Text('欧服'),
            trailing: Text('${value.$1.moneyFormat} ISK',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                )),
          ),
          ListTile(
            minTileHeight: 0,
            title: const Text('国服'),
            trailing: Text('${value.$2.moneyFormat} ISK',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                )),
          ),
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
