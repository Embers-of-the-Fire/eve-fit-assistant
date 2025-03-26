import 'package:eve_fit_assistant/pages/market/market_list.dart';
import 'package:flutter/material.dart';

class MarketPage extends StatelessWidget {
  const MarketPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('市场')),
        body: SafeArea(bottom: true, child: const MarketList()),
      );
}
