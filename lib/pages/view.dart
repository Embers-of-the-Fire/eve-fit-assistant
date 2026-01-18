import "dart:math" as math;

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/pages/character/page.dart";
import "package:eve_fit_assistant/pages/setting/page.dart";
import "package:eve_fit_assistant/pages/workspace/page.dart";
import "package:eve_fit_assistant/storage/loading_indicator.dart";
import "package:eve_fit_assistant/utils/context.dart";
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
    final loc = context.l10n;
    final pageTitles = [
      loc.frontPageTitleWorkspace,
      loc.frontPageTitleFitList,
      loc.frontPageTitleCharacter,
      loc.frontPageTitleSetting,
    ];
    const pages = <Widget>[
      WorkspacePage(),
      Center(child: Text("fit")),
      CharacterPage(),
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
        titleTextStyle: context.theme.appBarTheme.titleTextStyle?.copyWith(letterSpacing: 5),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        children: pages,
      ),
      // FloatingActionButton: docked in the center (notched BottomAppBar).
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      // Center docked so BottomAppBar shows a notch for the FAB.
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // BottomAppBar with internal Divider as top border (so notch clips it).
      bottomNavigationBar: BottomAppBar(
        color:
            context.theme.bottomNavigationBarTheme.backgroundColor ??
            context.theme.colorScheme.surface,
        elevation: 8,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: kBottomNavigationBarHeight,
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const Expanded(child: SizedBox()),
                        _NavItem(
                          index: 0,
                          icon: pageIcons[0],
                          label: pageTitles[0],
                          selected: _currentIndex == 0,
                          onTap: (idx) => _pageController
                              .animateToPage(
                                idx,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              )
                              .then((_) => setState(() => _currentIndex = idx)),
                        ),
                        const Expanded(child: SizedBox()),
                        _NavItem(
                          index: 1,
                          icon: pageIcons[1],
                          label: pageTitles[1],
                          selected: _currentIndex == 1,
                          onTap: (idx) => _pageController
                              .animateToPage(
                                idx,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              )
                              .then((_) => setState(() => _currentIndex = idx)),
                        ),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const Expanded(child: SizedBox()),
                        _NavItem(
                          index: 2,
                          icon: pageIcons[2],
                          label: pageTitles[2],
                          selected: _currentIndex == 2,
                          onTap: (idx) => _pageController
                              .animateToPage(
                                idx,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              )
                              .then((_) => setState(() => _currentIndex = idx)),
                        ),
                        const Expanded(child: SizedBox()),
                        _NavItem(
                          index: 3,
                          icon: pageIcons[3],
                          label: pageTitles[3],
                          selected: _currentIndex == 3,
                          onTap: (idx) => _pageController
                              .animateToPage(
                                idx,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              )
                              .then((_) => setState(() => _currentIndex = idx)),
                        ),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final IconData icon;
  final String label;
  final bool selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final selectedLabelStyle =
        Theme.of(context).bottomNavigationBarTheme.selectedLabelStyle ??
        Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 12) ??
        const TextStyle(fontSize: 12);
    const double iconSizeDefault = 24;
    final selectedIconTheme = Theme.of(context).bottomNavigationBarTheme.selectedIconTheme;
    final unselectedIconTheme = Theme.of(context).bottomNavigationBarTheme.unselectedIconTheme;
    final double selectedIconSize = selectedIconTheme?.size ?? iconSizeDefault;
    final double unselectedIconSize = unselectedIconTheme?.size ?? iconSizeDefault;

    final double selectedIconDiff = math.max(selectedIconSize - unselectedIconSize, 0);
    final double unselectedIconDiff = math.max(unselectedIconSize - selectedIconSize, 0);
    final double selectedFontSize = selectedLabelStyle.fontSize ?? 12.0;

    // Fixed tile width — keeps items compact between blank areas.
    const double tileWidth = 64;

    return SizedBox(
      width: tileWidth,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        tween: Tween<double>(begin: selected ? 0.0 : 1.0, end: selected ? 1.0 : 0.0),
        builder: (context, t, child) {
          final double bottomBegin = selectedIconDiff / 2.0;
          final double bottomEnd = selectedFontSize / 2.0 - unselectedIconDiff / 2.0;
          final double topBegin = selectedFontSize + selectedIconDiff / 2.0;
          final double topEnd = selectedFontSize / 2.0 - unselectedIconDiff / 2.0;

          final double bottomPadding = bottomBegin + (bottomEnd - bottomBegin) * t;
          final double topPadding = topBegin + (topEnd - topBegin) * t;
          final double iconSz = unselectedIconSize + (selectedIconSize - unselectedIconSize) * t;
          final Color selectedColor = Theme.of(context).colorScheme.primary;
          final Color unselectedColor = Theme.of(context).iconTheme.color ?? Colors.black;
          final Color iconColor = Color.lerp(unselectedColor, selectedColor, t)!;

          return InkResponse(
            onTap: () => onTap(index),
            child: Padding(
              padding: .only(top: topPadding, bottom: bottomPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: iconColor, size: iconSz),
                  Opacity(
                    opacity: t,
                    child: Padding(
                      padding: const .only(top: 2),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: selectedLabelStyle.copyWith(
                          color: iconColor,
                          fontSize: selectedLabelStyle.fontSize ?? 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
