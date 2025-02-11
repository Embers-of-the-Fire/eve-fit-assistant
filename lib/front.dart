library;

import 'dart:developer' as dev;

import 'package:eve_fit_assistant/pages/config.dart' as config_page;
import 'package:eve_fit_assistant/pages/main.dart' as main;
import 'package:eve_fit_assistant/pages/list.dart' as list;
import 'package:eve_fit_assistant/native/port/api/simple.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = const <Widget>[
      main.MainPage(),
      list.ListPage(),
      config_page.ConfigPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: _LoadingStatusIcon(),
        title: Text(_pageTitle[_currentIndex]),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() {
          _currentIndex = index;
        }),
        children: pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('提示'),
            content: Text(greet(name: 'Reamid')),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        ),
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

class _LoadingStatusIcon extends ConsumerWidget {
  const _LoadingStatusIcon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialized = ref.watch(globalStorageNotifierProvider);
    dev.log(
      'GlobalStorage initialized: $initialized',
      name: '_LoadingStatusIcon',
    );
    return initialized
        ? Icon(Icons.link)
        : LoadingIndicator(
            indicatorType: Indicator.ballClipRotateMultiple,
          );
  }
}
