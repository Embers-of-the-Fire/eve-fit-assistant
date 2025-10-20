import "package:flutter/material.dart";

class Layout extends StatelessWidget {
  const Layout({required this.title, required this.child, super.key, this.bottom});
  final Widget child;
  final String title;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), bottom: bottom),
    body: child,
  );
}
