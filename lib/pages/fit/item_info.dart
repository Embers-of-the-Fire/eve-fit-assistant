import 'package:flutter/material.dart';

Future<void> showItemInfoPage(BuildContext context) async {
  await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ItemInfoPage()));
}

class ItemInfoPage extends StatelessWidget {
  const ItemInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('物品信息'),
      ),
      body: const Center(
          child: Text(
        'Work in Progress',
        style: TextStyle(fontSize: 36),
      )),
    );
  }
}
