import 'package:eve_fit_assistant/pages/announcement.dart';
import 'package:eve_fit_assistant/pages/character/character.dart';
import 'package:eve_fit_assistant/pages/create.dart';
import 'package:eve_fit_assistant/pages/market.dart';
import 'package:eve_fit_assistant/pages/skill_list.dart';
import 'package:flutter/material.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) => Scrollbar(
          child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        scrollDirection: Axis.vertical,
        controller: _scrollController,
        children: [
          MainPageCard(
            onTap: () => startFitCreation(context),
            icon: Icons.add,
            text: '创建新配置',
            height: 150,
          ),
          const SizedBox(height: 20),
          MainPageCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const CharacterPage()),
            ),
            icon: Icons.account_circle_outlined,
            text: '角色配置',
            height: 150,
          ),
          const SizedBox(height: 20),
          MainPageCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AnnouncementPage()),
            ),
            icon: Icons.list,
            text: '公告',
            height: 150,
          ),
          const SizedBox(height: 20),
          MainPageCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const MarketPage()),
            ),
            text: '物品市场',
            icon: Icons.shopping_cart_outlined,
            height: 150,
          ),
          const SizedBox(height: 20),
          MainPageCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SkillListPage()),
            ),
            icon: Icons.account_tree_outlined,
            text: '技能列表',
            height: 150,
          ),
        ],
      ));
}

class MainPageCard extends StatelessWidget {
  final void Function() onTap;
  final Color? color;
  final IconData? icon;
  final double? height;
  final String text;

  const MainPageCard({
    super.key,
    this.color,
    required this.onTap,
    this.icon,
    this.height,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> row = [];
    if (icon != null) {
      row.add(Container(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(
            icon,
            size: 34,
            color: Colors.blue.shade800,
          )));
    }
    row.add(Text(
      text,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.blue.shade800,
      ),
    ));
    return Container(
      padding: const EdgeInsets.only(left: 30, right: 30),
      height: height,
      child: Card(
        color: color ?? Colors.white70,
        elevation: 10.0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
        clipBehavior: Clip.antiAlias,
        semanticContainer: false,
        child: InkWell(
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            child: Row(
              spacing: 10,
              mainAxisAlignment: MainAxisAlignment.center,
              children: row,
            ),
          ),
        ),
      ),
    );
  }
}
