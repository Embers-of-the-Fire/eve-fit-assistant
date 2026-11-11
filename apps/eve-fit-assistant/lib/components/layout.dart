import "package:flutter/material.dart";

class Layout extends StatelessWidget {
  const Layout({
    required this.title,
    required this.child,
    super.key,
    this.bottom,
    this.actions,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.scaffoldKey,
    this.endDrawer,
    this.onEndDrawerChanged,
  });
  final Widget child;
  final String title;
  final PreferredSizeWidget? bottom;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final Widget? endDrawer;
  final ValueChanged<bool>? onEndDrawerChanged;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: scaffoldKey,
    appBar: AppBar(title: Text(title), bottom: bottom, actions: actions),
    endDrawer: endDrawer,
    onEndDrawerChanged: onEndDrawerChanged,
    body: SafeArea(child: child),
    floatingActionButton: floatingActionButton,
    floatingActionButtonLocation: floatingActionButtonLocation,
  );
}
