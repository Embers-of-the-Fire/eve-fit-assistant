import 'package:eve_fit_assistant/pages/account/fittings.dart';
import 'package:eve_fit_assistant/widgets/card.dart';
import 'package:eve_fit_assistant/widgets/grid.dart';
import 'package:flutter/material.dart';

class AccountPanel extends StatelessWidget {
  const AccountPanel({super.key});

  @override
  Widget build(BuildContext context) => Scrollbar(
          child: FixedHeightGridView(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childHeight: 160,
        children: [
          FunctionCard(
              onTap: () {},
              icon: Icons.account_tree_outlined,
              title: '技能',
              color: const Color(0xFF9A4DFF)),
          FunctionCard(
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (context) => const FittingsPage())),
              icon: Icons.memory,
              title: '装配',
              color: const Color(0xFF00F7FF)),
        ],
      ));
}
