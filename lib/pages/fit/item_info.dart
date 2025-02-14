import 'package:flutter/material.dart';

Future<void> showItemInfoPage(BuildContext context) async {
  await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ItemInfoPage()));
}

class ItemInfoPage extends StatelessWidget {
  const ItemInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    // return SimpleDialog(
    //   title: const Text('Item Info'),
    //   children: <Widget>[
    //     ListTile(
    //       title: const Text('Item Name'),
    //       subtitle: const Text('Item Description'),
    //     ),
    //   ],
    // );
    // return const Placeholder();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('物品信息'),
      ),
    );
  }
}
