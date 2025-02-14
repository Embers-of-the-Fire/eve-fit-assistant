import 'package:eve_fit_assistant/pages/config/asset.dart';
import 'package:eve_fit_assistant/pages/config/info.dart';
import 'package:eve_fit_assistant/utils/external_icon_icons.dart';
import 'package:flutter/material.dart';

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.vertical,
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text('关于'),
          onTap: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const InfoPage())),
        ),
        ListTile(
          leading: const Icon(ExternalIcon.cubes),
          title: const Text('资产管理'),
          onTap: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AssetPage())),
        )
      ],
    );
  }
}
