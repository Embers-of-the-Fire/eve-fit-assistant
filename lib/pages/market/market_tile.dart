part of 'market_list.dart';

class MarketPriceGroup {
  final int typeID;
  final MarketPrice tranquility;
  final MarketPrice serenity;

  const MarketPriceGroup({
    required this.typeID,
    required this.tranquility,
    required this.serenity,
  });
}

@riverpod
Future<MarketPriceGroup> getMarketPrice(Ref ref, int typeID, int timestamp) async =>
    MarketPriceGroup(
        typeID: typeID,
        tranquility: await GlobalStorage().market.getPrice(typeID, Server.tranquility),
        serenity: await GlobalStorage().market.getPrice(typeID, Server.serenity));

class MarketListTile extends ConsumerWidget {
  final String name;
  final int typeID;
  final int timestamp;
  final void Function() onLongPress;
  final void Function() onTap;

  const MarketListTile({
    super.key,
    required this.name,
    required this.typeID,
    required this.timestamp,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prices = ref.watch(getMarketPriceProvider(typeID, timestamp));

    final desc = switch (prices) {
      AsyncError(:final error) => ListTile(
          leading: const SizedBox(width: 32),
          subtitle: Text('网络连接出错：$error', softWrap: true),
        ),
      AsyncData(:final value) => ListTile(
          title: Text('欧服：买单：${value.tranquility.summary.buy.max.moneyFormat}\n'
              '　　　卖单：${value.tranquility.summary.sell.min.moneyFormat}\n'
              '国服：买单：${value.serenity.summary.buy.max.moneyFormat}\n'
              '　　　卖单：${value.serenity.summary.sell.min.moneyFormat}'),
        ),
      AsyncLoading() || _ => const ListTile(
            title: Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 10, children: [
          SizedBox(
              width: 24,
              height: 24,
              child: LoadingIndicator(indicatorType: Indicator.lineScale, colors: [Colors.white])),
          Text('加载中...')
        ]))
    };

    return InkWell(
        onLongPress: onLongPress,
        onTap: onTap,
        child: Column(
          children: [
            ListTile(
                leading: GlobalStorage().static.icons.getTypeIconSync(typeID),
                title: Text(name, softWrap: true)),
            desc,
            const Divider(height: 0),
          ],
        ));
  }
}
