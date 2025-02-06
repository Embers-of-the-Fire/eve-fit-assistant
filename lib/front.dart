library;

import 'package:eve_fit_assistant/pages/config.dart' as config_page;
import 'package:eve_fit_assistant/pages/main.dart' as main;
import 'package:flutter/material.dart';
import 'package:loading_indicator/loading_indicator.dart';

class FrontendPage extends StatefulWidget {
  const FrontendPage({super.key});

  @override
  State<FrontendPage> createState() => _FrontendPageState();
}

class _FrontendPageState extends State<FrontendPage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  final _pageTitle = const ['主页', '列表', '设置'];

  final _pages = const <Widget>[
    main.MainPage(),
    Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            '列表',
          ),
        ],
      ),
    ),
    config_page.ConfigPage(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: LoadingIndicator(
          indicatorType: Indicator.ballClipRotateMultiple,
          pause: true,
        ),
        title: Text(_pageTitle[_currentIndex]),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() {
          _currentIndex = index;
        }),
        children: _pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        shape: CircleBorder(),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        showSelectedLabels: true,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: '主页',
              backgroundColor: Colors.red),
          BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_rounded),
              label: '列表',
              backgroundColor: Colors.blue),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: '设置',
              backgroundColor: Colors.yellow),
        ],
      ),
    );
  }
}
