part of '../preference.dart';

class MarketApiTile extends StatefulWidget {
  const MarketApiTile({super.key});

  @override
  State<MarketApiTile> createState() => _MarketApiTileState();
}

class _MarketApiTileState extends State<MarketApiTile> {
  MarketApi value = MarketApi.esi;

  @override
  void initState() {
    value = GlobalPreference.marketApi;
    super.initState();
  }

  @override
  Widget build(BuildContext context) => ListTile(
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
                  GlobalPreference.marketApi = value;
                  this.value = value;
                })),
      );
}
