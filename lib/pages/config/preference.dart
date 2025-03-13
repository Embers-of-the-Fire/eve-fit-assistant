import 'package:eve_fit_assistant/storage/preference/preference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part './preference/debug.dart';
part './preference/item_list_behavior.dart';
part './preference/market_api.dart';
part './preference/esi_auth_behavior.dart';

class PreferencePage extends StatelessWidget {
  const PreferencePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('偏好设置'),
          centerTitle: true,
        ),
        body: ListView(children: const [
          ListTile(
              minTileHeight: 0,
              title: Text('物品列表',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ))),
          Divider(height: 0),
          ItemListPopBehaviorTile(),
          Divider(height: 0),
          ListTile(
              minTileHeight: 0,
              title: Text('市场',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ))),
          Divider(height: 0),
          MarketApiTile(),
          Divider(height: 0),
          ListTile(
              minTileHeight: 0,
              title: Text('授权',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ))),
          Divider(height: 0),
          EsiAuthBehaviorTile(),
          EsiAuthServerTile(),
          Divider(height: 0),
          ListTile(
              minTileHeight: 0,
              title: Text('开发者',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ))),
          Divider(height: 0),
          DebugTile(),
          Divider(height: 0),
        ]),
      );
}
