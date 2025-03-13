import 'package:flutter/material.dart';

class AccountPanel extends StatelessWidget {
  const AccountPanel({super.key});

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        scrollDirection: Axis.vertical,
        children: [
          SizedBox(
              height: 100, child: InkWell(onTap: () {}, child: const Center(child: Text('abc')))),
          SizedBox(
              height: 100, child: InkWell(onTap: () {}, child: const Center(child: Text('def')))),
        ],
      );
}
