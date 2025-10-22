import "package:flutter/material.dart";

class Layout extends StatelessWidget {
  const Layout({
    required this.title,
    required this.child,
    super.key,
    this.bottom,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });
  final Widget child;
  final String title;
  final PreferredSizeWidget? bottom;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), bottom: bottom),
    body: child,
    floatingActionButton: floatingActionButton,
    floatingActionButtonLocation: floatingActionButtonLocation,
  );
}
