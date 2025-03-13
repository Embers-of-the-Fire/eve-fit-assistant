library;

import 'dart:developer' as dev;

import 'package:eve_fit_assistant/pages/account/account.dart' as account_page;
import 'package:eve_fit_assistant/pages/config.dart' as config_page;
import 'package:eve_fit_assistant/pages/create.dart';
import 'package:eve_fit_assistant/pages/list.dart' as list_page;
import 'package:eve_fit_assistant/pages/main.dart' as main_page;
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_indicator/loading_indicator.dart';

class FrontendPage extends StatefulWidget {
  const FrontendPage({super.key});

  @override
  State<FrontendPage> createState() => _FrontendPageState();
}

const _pageTitle = ['工作台', '列表', '角色', '设置'];
const _noFloatingActionButton = [2, 3];

class _FrontendPageState extends State<FrontendPage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const pages = <Widget>[
      main_page.MainPage(),
      list_page.ListPage(),
      account_page.AccountPage(),
      config_page.ConfigPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: const _LoadingStatusIcon(),
        title: Text(_pageTitle[_currentIndex]),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() {
          _currentIndex = index;
        }),
        children: pages,
      ),
      floatingActionButton:
          (!_noFloatingActionButton.contains(_currentIndex)).then(() => FloatingActionButton(
                onPressed: () => startFitCreation(context),
                shape: const CircleBorder(),
                child: const Icon(Icons.add),
              )),
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
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: '工作台'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: '列表'),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: '角色'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: '设置'),
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
        ? const Icon(Icons.link)
        : const LoadingIndicator(
            indicatorType: Indicator.ballClipRotateMultiple,
          );
  }
}
