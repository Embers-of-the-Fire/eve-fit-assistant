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
          leading: Icon(Icons.info_outline_rounded),
          title: Text('关于'),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (context) => InfoPage())),
        ),
        ListTile(
          leading: Icon(ExternalIcon.cubes),
          title: Text('资产管理'),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (context) => AssetPage())),
        )
      ],
    );
  }
}
