import 'package:flutter/material.dart';

class Layout extends StatelessWidget {
  final Widget child;
  final String title;
  final PreferredSizeWidget? bottom;

  const Layout({super.key, required this.title, this.bottom, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), bottom: bottom),
      body: child,
    );
  }
}
