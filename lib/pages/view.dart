import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/pages/setting/page.dart";
import "package:eve_fit_assistant/pages/workspace/page.dart";
import "package:eve_fit_assistant/storage/loading_indicator.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:eve_fit_assistant/utils/l10n.dart";
import "package:flutter/material.dart";

@RoutePage()
class FrontPage extends StatefulWidget {
  const FrontPage({super.key});

  @override
  State<FrontPage> createState() => _FrontPageState();
}

class _FrontPageState extends State<FrontPage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    final loc = l10n(context);
    final pageTitles = [
      loc.frontPageTitleWorkspace,
      loc.frontPageTitleFitList,
      loc.frontPageTitleCharacter,
      loc.frontPageTitleSetting,
    ];
    const noFloatingActionButton = {2, 3};
    const pages = <Widget>[
      WorkspacePage(),
      Center(child: Text("fit")),
      Center(child: Text("char")),
      SettingPage(),
    ];
    const pageIcons = <IconData>[
      Icons.dashboard_rounded,
      Icons.list_alt_rounded,
      Icons.account_circle,
      Icons.settings_rounded,
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const StorageLoadingIndicator(),
        title: Text(pageTitles[_currentIndex]),
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(letterSpacing: 5),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        children: pages,
      ),
      floatingActionButton: BoolThen(!noFloatingActionButton.contains(_currentIndex))
          .then(
            () => FloatingActionButton(
              onPressed: () {},
              shape: const CircleBorder(),
              child: const Icon(Icons.add),
            ),
          )
          .toNullable(),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 2)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => _pageController
              .animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              )
              .then((_) => setState(() => _currentIndex = index)),
          showSelectedLabels: true,
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
          items: pageTitles
              .enumerate()
              .map(
                (args) => BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Icon(pageIcons[args.$1]),
                  ),
                  label: args.$2,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
