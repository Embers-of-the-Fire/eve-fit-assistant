import 'package:eve_fit_assistant/pages/announcement.dart';
import 'package:eve_fit_assistant/pages/character/character.dart';
import 'package:eve_fit_assistant/pages/create.dart';
import 'package:eve_fit_assistant/pages/market.dart';
import 'package:eve_fit_assistant/pages/skill_list.dart';
import 'package:eve_fit_assistant/widgets/card.dart';
import 'package:eve_fit_assistant/widgets/grid.dart';
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
          child: FixedHeightGridView(
        padding: const EdgeInsets.all(20),
        controller: _scrollController,
        crossAxisCount: 2,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childHeight: 160,
        children: [
          FunctionCard(
              onTap: () => startFitCreation(context),
              icon: Icons.add,
              title: '创建新配置',
              color: const Color(0xFF00F7FF)),
          FunctionCard(
              onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const CharacterPage()),
                  ),
              icon: Icons.account_circle_outlined,
              title: '角色配置',
              color: const Color(0xFF00F7FF)),
          FunctionCard(
              onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AnnouncementPage()),
                  ),
              icon: Icons.list,
              title: '公告',
              color: const Color(0xFFFFD600)),
          FunctionCard(
              onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const MarketPage()),
                  ),
              title: '物品市场',
              icon: Icons.shopping_cart_outlined,
              color: const Color(0xFF9A4DFF)),
          FunctionCard(
              onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SkillListPage()),
                  ),
              icon: Icons.account_tree_outlined,
              title: '技能列表',
              color: const Color(0xFF9A4DFF)),
        ],
      ));
}
