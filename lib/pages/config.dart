import 'package:eve_fit_assistant/pages/config/account.dart';
import 'package:eve_fit_assistant/pages/config/asset.dart';
import 'package:eve_fit_assistant/pages/config/info.dart';
import 'package:eve_fit_assistant/pages/config/preference.dart';
import 'package:eve_fit_assistant/pages/config/version.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:eve_fit_assistant/widgets/external_icon_icons.dart';
import 'package:flutter/material.dart';

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        scrollDirection: Axis.vertical,
        children: [
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: const Text('账户'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AccountPage()),
            ),
          ),
          const Divider(height: 0),
          const SizedBox(height: 20),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(ExternalIcon.cubes),
            title: const Text('资产管理'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AssetPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('偏好设置'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const PreferencePage()),
            ),
          ),
          const Divider(height: 0),
          const SizedBox(height: 20),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.update),
            title: const Text('版本'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const VersionPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.copyright),
            title: const Text('版权'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (builder) => Theme(
                      data: Theme.of(context).let((u) => u.copyWith(
                            appBarTheme: u.appBarTheme,
                            cardColor: u.scaffoldBackgroundColor,
                          )),
                      child: const LicensePage(),
                    ))),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('关于'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const InfoPage()),
            ),
          ),
          const Divider(height: 0),
        ],
      );
}
