import 'package:flutter/material.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final _scrollController = ScrollController();

  final _cards = <Widget>[
    MainPageCard(
      onTap: () {},
      icon: Icons.add,
      text: '创建新配置',
      height: 150,
    ),
    SizedBox(height: 20),
    MainPageCard(
      onTap: () {},
      text: '物品市场',
      icon: Icons.shopping_cart_rounded,
      height: 150,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(top: 20, bottom: 20),
      scrollDirection: Axis.vertical,
      controller: _scrollController,
      children: _cards,
    );
  }
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
          padding: EdgeInsets.only(top: 4),
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
      padding: EdgeInsets.only(left: 30, right: 30),
      height: height,
      child: Card(
        color: color ?? Colors.white70,
        elevation: 10.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
        clipBehavior: Clip.antiAlias,
        semanticContainer: false,
        child: InkWell(
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row,
            ),
          ),
        ),
      ),
    );
  }
}
