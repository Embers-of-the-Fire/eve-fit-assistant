import 'package:eve_fit_assistant/storage/static/bundle.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/widgets/dialog.dart';
import 'package:eve_fit_assistant/widgets/external_icon_icons.dart';
import 'package:flutter/material.dart';

class AssetPage extends StatelessWidget {
  const AssetPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('资产管理'),
          centerTitle: true,
        ),
        body: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: ListView(
              children: [
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('本地存储版本'),
                  trailing: Text(
                    GlobalStorage().version.version.toString(),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AppDialog(
                              title: '清除本地存储',
                              content: const Text('确定要清除本地存储吗？\n这将会初始化所有本地存储数据。'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop(false);
                                  },
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop(true);
                                  },
                                  child: const Text('确定'),
                                ),
                              ],
                            ));
                    if (confirm == null || confirm == false) return;
                    await clearStorage();
                  },
                  child: Text(
                    '清除本地存储',
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontSize: 18,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.red.shade600,
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(ExternalIcon.cubes),
                  title: const Text('静态资产版本'),
                  trailing: Text(
                    GlobalStorage().static.version?.display() ?? '未知',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AppDialog(
                              title: '重置静态资产',
                              content: const Text('确定要重置静态资产吗？'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop(false);
                                  },
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop(true);
                                  },
                                  child: const Text('确定'),
                                ),
                              ],
                            ));
                    if (confirm ?? false) {
                      await clearStaticStorage();
                      await unpackBundledStorage();
                    }
                  },
                  child: Text(
                    '重置静态资产',
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontSize: 18,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.red.shade600,
                    ),
                  ),
                ),
                const Divider(height: 8),
              ],
            )),
      );
}
