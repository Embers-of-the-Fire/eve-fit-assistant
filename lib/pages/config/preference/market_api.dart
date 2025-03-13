part of '../preference.dart';

class MarketApiTile extends ConsumerStatefulWidget {
  const MarketApiTile({super.key});

  @override
  ConsumerState<MarketApiTile> createState() => _MarketApiTileState();
}

class _MarketApiTileState extends ConsumerState<MarketApiTile> {
  MarketApi value = MarketApi.esi;

  @override
  void initState() {
    super.initState();
    value = ref.read(globalPreferenceProvider).preference.marketApi;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(globalPreferenceProvider.notifier);

    return ListTile(
      title: const Text('市场数据 API'),
      subtitle: const Text('市场数据的来源。\nESI: EVE 官方接口\nCEVE Market: 国服市场中心公开API'),
      trailing: DropdownButton(
          value: value,
          items: const <DropdownMenuItem<MarketApi>>[
            DropdownMenuItem(value: MarketApi.esi, child: Text('ESI')),
            DropdownMenuItem(value: MarketApi.cEveMarket, child: Text('CEVE Market')),
          ],
          onChanged: (value) => setState(() {
                if (value == null) return;
                notifier.modify((preference) => preference.marketApi = value);
                this.value = value;
              })),
    );
  }
}
